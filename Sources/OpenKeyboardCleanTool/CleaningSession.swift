import AppKit
import ApplicationServices

@MainActor
final class CleaningSession: ObservableObject {
    enum State: Equatable {
        case idle
        case checkingPermission
        case awaitingPermission
        case locked
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    private let blocker = KeyboardBlocker()
    private let isAccessibilityTrusted: () -> Bool
    private let promptForAccessibility: () -> Void
    private var terminationObserver: NSObjectProtocol?

    init(
        isAccessibilityTrusted: @escaping () -> Bool = { AXIsProcessTrusted() },
        promptForAccessibility: @escaping () -> Void = {
            let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
            AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
        }
    ) {
        self.isAccessibilityTrusted = isAccessibilityTrusted
        self.promptForAccessibility = promptForAccessibility
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.blocker.stop()
            }
        }
    }

    func launch(autoLock: Bool) {
        guard autoLock, state == .idle else { return }
        startCleaning()
    }

    func startCleaning() {
        guard state != .locked else { return }

        if isAccessibilityTrusted() {
            lockKeyboard()
        } else {
            state = .awaitingPermission
            promptForAccessibility()
        }
    }

    func checkPermissionAgain() {
        state = .checkingPermission
        if isAccessibilityTrusted() {
            lockKeyboard()
        } else {
            state = .awaitingPermission
        }
    }

    func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    func finishAndQuit() {
        blocker.stop()
        NSApplication.shared.terminate(nil)
    }

    private func lockKeyboard() {
        // A failed or system-disabled tap must never poison a later retry.
        blocker.stop()
        do {
            try blocker.start()
            guard blocker.isRunning else {
                blocker.stop()
                state = .failed("The keyboard blocker did not become active.")
                return
            }
            state = .locked
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    deinit {
        if let terminationObserver {
            NotificationCenter.default.removeObserver(terminationObserver)
        }
        blocker.stop()
    }
}
