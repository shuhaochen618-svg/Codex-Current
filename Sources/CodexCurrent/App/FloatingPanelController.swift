import AppKit
import Combine
import SwiftUI

@MainActor
final class FloatingPanelController: NSObject, ObservableObject, NSWindowDelegate {
    @Published private(set) var isVisible = false

    private let model: AppModel
    private var panel: NSPanel?
    private var cancellables: Set<AnyCancellable> = []

    init(model: AppModel) {
        self.model = model
        super.init()
        model.preferences.$isPinned
            .removeDuplicates()
            .sink { [weak self] isPinned in
                self?.applyPinned(isPinned)
            }
            .store(in: &cancellables)
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        let panel = panel ?? makePanel()
        applyPinned(model.preferences.isPinned)
        panel.orderFrontRegardless()
        isVisible = true
        Task { await model.refresh() }
    }

    func hide() {
        panel?.orderOut(nil)
        isVisible = false
    }

    func windowWillClose(_ notification: Notification) {
        isVisible = false
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 620),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = L10n.text("app.name")
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isReleasedWhenClosed = false
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.minSize = NSSize(width: 350, height: 300)
        panel.maxSize = NSSize(width: 560, height: 900)
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: DashboardView(model: model))
        panel.center()
        self.panel = panel
        return panel
    }

    private func applyPinned(_ isPinned: Bool) {
        panel?.level = isPinned ? .floating : .normal
    }
}
