import AppKit
import SwiftUI

private let windowCornerRadius: CGFloat = 28
private let windowSize = NSSize(width: 460, height: 440)

@main
struct OpenKeyboardCleanToolApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: BorderlessWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let session = CleaningSession()
        let rootView = CleaningView()
            .environmentObject(session)
            .frame(width: windowSize.width, height: windowSize.height)

        let window = BorderlessWindow(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSHostingView(rootView: rootView)
        window.isMovableByWindowBackground = true
        window.isOpaque = false
        window.backgroundColor = .clear
        // The surface fills the window, so any outer shadow would be clipped to
        // this rectangular backing store and become visible in the four corners.
        window.hasShadow = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        self.window = window
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

private final class BorderlessWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

private struct CleaningView: View {
    @EnvironmentObject private var session: CleaningSession
    @AppStorage("lockOnLaunch") private var lockOnLaunch = false
    @AppStorage("quitAfterCleaning") private var quitAfterCleaning = true
    @State private var didHandleLaunch = false

    var body: some View {
        adaptiveSurface
            .ignoresSafeArea()
            .overlay(alignment: .topTrailing) {
                closeButton
                    .padding(18)
            }
            .onAppear {
                guard !didHandleLaunch else { return }
                didHandleLaunch = true
                session.launch(autoLock: lockOnLaunch)
            }
    }

    @ViewBuilder
    private var adaptiveSurface: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 12) {
                content
                    .glassEffect(
                        .regular.tint(stateColor.opacity(0.1)),
                        in: RoundedRectangle(cornerRadius: windowCornerRadius, style: .continuous)
                    )
            }
        } else {
            content
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: windowCornerRadius, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: windowCornerRadius, style: .continuous)
                        .stroke(.white.opacity(0.16), lineWidth: 1)
                }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 34)

            symbol

            Text(title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .padding(.top, 20)

            Text(message)
                .font(.system(size: 14.5))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 330)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            controls
                .padding(.top, 24)

            Spacer(minLength: 24)

            preferences
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            LinearGradient(
                colors: [stateColor.opacity(0.13), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: windowCornerRadius, style: .continuous))
    }

    private var symbol: some View {
        ZStack {
            Circle()
                .fill(stateColor.opacity(0.12))
                .frame(width: 88, height: 88)

            Image(systemName: iconName)
                .font(.system(size: 40, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(stateColor)
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch session.state {
        case .idle:
            primaryButton("Start Cleaning") { session.startCleaning() }
        case .checkingPermission:
            ProgressView()
                .controlSize(.large)
                .frame(height: 44)
        case .awaitingPermission:
            VStack(spacing: 10) {
                primaryButton("Open System Settings") {
                    session.openAccessibilitySettings()
                }
                secondaryButton("Check Again") { session.checkPermissionAgain() }
            }
        case .locked:
            primaryButton("Finish Cleaning") {
                session.finishCleaning(quitAfter: quitAfterCleaning)
            }
        case .failed:
            VStack(spacing: 10) {
                primaryButton("Try Again") { session.checkPermissionAgain() }
                secondaryButton("Quit") { session.finishAndQuit() }
            }
        }
    }

    private var preferences: some View {
        VStack(spacing: 0) {
            preferenceRow(
                title: "Lock immediately on launch",
                detail: "Start cleaning as soon as the app opens.",
                isOn: $lockOnLaunch
            )

            Divider()
                .padding(.leading, 16)

            preferenceRow(
                title: "Quit after cleaning",
                detail: "Close the app when cleaning is finished.",
                isOn: $quitAfterCleaning
            )
        }
        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14))
    }

    private func preferenceRow(
        title: String,
        detail: String,
        isOn: Binding<Bool>
    ) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    @ViewBuilder
    private var closeButton: some View {
        Button {
            session.finishAndQuit()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .bold))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .background(.primary.opacity(0.07), in: Circle())
        .contentShape(Circle())
        .help("Quit")
    }

    @ViewBuilder
    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        if #available(macOS 26.0, *) {
            Button(title, action: action)
                .buttonStyle(.glassProminent)
                .tint(stateColor)
                .controlSize(.large)
        } else {
            Button(title, action: action)
                .buttonStyle(.borderedProminent)
                .tint(stateColor)
                .controlSize(.large)
        }
    }

    @ViewBuilder
    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        if #available(macOS 26.0, *) {
            Button(title, action: action)
                .buttonStyle(.glass)
                .controlSize(.large)
        } else {
            Button(title, action: action)
                .buttonStyle(.bordered)
                .controlSize(.large)
        }
    }

    private var title: String {
        switch session.state {
        case .idle: "Clean Your Keyboard"
        case .checkingPermission: "Getting Ready"
        case .awaitingPermission: "Permission Needed"
        case .locked: "Keyboard Locked"
        case .failed: "Couldn’t Lock Keyboard"
        }
    }

    private var message: String {
        switch session.state {
        case .idle:
            "Temporarily block every key while your mouse and trackpad stay active."
        case .checkingPermission:
            "Starting keyboard protection…"
        case .awaitingPermission:
            "Allow Accessibility access, then return here and check again."
        case .locked:
            "Clean freely. Click Finish Cleaning when you’re done."
        case .failed(let reason):
            reason
        }
    }

    private var iconName: String {
        switch session.state {
        case .idle, .checkingPermission: "keyboard"
        case .awaitingPermission: "lock.open"
        case .locked: "keyboard.badge.ellipsis"
        case .failed: "exclamationmark.triangle"
        }
    }

    private var stateColor: Color {
        switch session.state {
        case .idle, .checkingPermission: .blue
        case .awaitingPermission: .orange
        case .locked: .green
        case .failed: .red
        }
    }
}
