// MARK: - PlatformHelpers.swift
// Unified platform abstractions for cross-platform iOS & macOS compatibility

import SwiftUI
#if os(iOS)
import UIKit
import Clarity
#elseif os(macOS)
import AppKit
#endif

enum HapticFeedback {
    case light
    case medium
    case heavy
    case success
    case error

    static func trigger(_ type: HapticFeedback = .medium) {
        #if os(iOS)
        switch type {
        case .light:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .heavy:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        #elseif os(macOS)
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        #endif
    }
}

enum PlatformURLOpener {
    static func open(_ url: URL) {
        #if os(iOS)
        UIApplication.shared.open(url)
        #elseif os(macOS)
        NSWorkspace.shared.open(url)
        #endif
    }

    static func openSettings() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #elseif os(macOS)
        if let url = URL(string: "x-apple.systempreferences:") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }
}

#if os(macOS)
extension View {
    @ViewBuilder
    func sortydPageTabViewStyle() -> some View {
        self
    }
}
#else
extension View {
    @ViewBuilder
    func sortydPageTabViewStyle() -> some View {
        self.tabViewStyle(.page(indexDisplayMode: .never))
    }
}
#endif

#if os(iOS)
var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
#else
var isPad: Bool { false }
#endif

extension View {
    @ViewBuilder
    func sortydClarityMask() -> some View {
        #if os(iOS)
        self.clarityMask()
        #else
        self
        #endif
    }
}

extension Notification.Name {
    #if os(iOS)
    static let appWillEnterForeground = UIApplication.willEnterForegroundNotification
    #elseif os(macOS)
    static let appWillEnterForeground = NSApplication.willBecomeActiveNotification
    #endif
}

#if os(macOS)
enum EditMode {
    case active
    case inactive
    case transient
    var isEditing: Bool { self == .active }
}

enum NavigationBarItem {
    enum TitleDisplayMode {
        case inline
        case large
        case automatic
    }
}

enum UIKeyboardType {
    case numberPad
    case decimalPad
    case `default`
}

extension View {
    func navigationBarTitleDisplayMode(_ mode: NavigationBarItem.TitleDisplayMode) -> some View {
        self
    }

    func navigationBarHidden(_ hidden: Bool) -> some View {
        self
    }

    func listRowSpacing(_ spacing: CGFloat) -> some View {
        self
    }

    func keyboardType(_ type: UIKeyboardType) -> some View {
        self
    }

    func fullScreenCover<Content: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.sheet(isPresented: isPresented, onDismiss: onDismiss, content: content)
    }
}

extension ToolbarItemPlacement {
    static var navigationBarLeading: ToolbarItemPlacement { .navigation }
    static var navigationBarTrailing: ToolbarItemPlacement { .primaryAction }
}

extension ToolbarPlacement {
    static var navigationBar: ToolbarPlacement { .automatic }
}
#endif
