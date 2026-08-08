import CoreGraphics
import XCTest
@testable import OpenKeyboardCleanTool

final class KeyboardBlockerTests: XCTestCase {
    @MainActor
    func testManualLaunchDoesNotPromptOrLock() {
        var promptCount = 0
        let session = CleaningSession(
            isAccessibilityTrusted: { false },
            promptForAccessibility: { promptCount += 1 }
        )

        session.launch(autoLock: false)

        XCTAssertEqual(promptCount, 0)
        XCTAssertEqual(session.state, .idle)
    }

    @MainActor
    func testPermissionRecheckDoesNotPromptAgain() {
        var promptCount = 0
        let session = CleaningSession(
            isAccessibilityTrusted: { false },
            promptForAccessibility: { promptCount += 1 }
        )

        session.launch(autoLock: true)
        XCTAssertEqual(promptCount, 1)

        session.checkPermissionAgain()
        XCTAssertEqual(promptCount, 1)
        XCTAssertEqual(session.state, .awaitingPermission)
    }

    func testKeyboardEventsAreBlocked() {
        let keyboardEvents: [CGEventType] = [
            .keyDown,
            .keyUp,
            .flagsChanged,
            CGEventType(rawValue: 14)!
        ]

        for eventType in keyboardEvents {
            XCTAssertTrue(KeyboardBlocker.shouldBlock(eventType))
        }
    }

    func testPointerAndTapLifecycleEventsPassThrough() {
        let allowedEvents: [CGEventType] = [
            .leftMouseDown,
            .leftMouseUp,
            .mouseMoved,
            .scrollWheel,
            .tapDisabledByTimeout,
            .tapDisabledByUserInput
        ]

        for eventType in allowedEvents {
            XCTAssertFalse(KeyboardBlocker.shouldBlock(eventType))
        }
    }
}
