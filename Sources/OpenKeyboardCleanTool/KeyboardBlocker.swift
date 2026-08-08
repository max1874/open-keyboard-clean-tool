import CoreGraphics
import Foundation

final class KeyboardBlocker {
    enum StartError: LocalizedError {
        case eventTapUnavailable

        var errorDescription: String? {
            "macOS did not allow the keyboard event tap to start."
        }
    }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var isRunning: Bool {
        guard let eventTap else { return false }
        return CGEvent.tapIsEnabled(tap: eventTap)
    }

    func start() throws {
        guard eventTap == nil else { return }

        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: Self.eventMask,
            callback: keyboardEventCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        guard let tap else {
            throw StartError.eventTapUnavailable
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        runLoopSource = nil
        eventTap = nil
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        return Self.shouldBlock(type) ? nil : Unmanaged.passUnretained(event)
    }

    static func shouldBlock(_ type: CGEventType) -> Bool {
        switch type {
        case .keyDown, .keyUp, .flagsChanged:
            return true
        default:
            return type.rawValue == Self.systemDefinedEventType.rawValue
        }
    }

    private static let eventMask: CGEventMask = [
        CGEventType.keyDown,
        .keyUp,
        .flagsChanged,
        systemDefinedEventType
    ].reduce(0) { mask, type in
        mask | (CGEventMask(1) << CGEventMask(type.rawValue))
    }

    // Quartz exposes NX_SYSDEFINED (media, brightness, and similar keys) as
    // event type 14, but CGEventType does not publish a named Swift constant.
    private static let systemDefinedEventType = CGEventType(rawValue: 14)!

    deinit {
        stop()
    }
}

private func keyboardEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let blocker = Unmanaged<KeyboardBlocker>.fromOpaque(userInfo).takeUnretainedValue()
    return blocker.handle(type: type, event: event)
}
