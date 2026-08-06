import AppKit
import Combine
import SwiftUI

@MainActor
final class FloatingPanelController: NSObject, ObservableObject, NSWindowDelegate {
    @Published private(set) var isVisible = false

    private let model: AppModel
    private var panel: NSPanel?
    private var preferredContentHeight: CGFloat?
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

    func windowDidChangeScreen(_ notification: Notification) {
        guard let preferredContentHeight else { return }
        resizeForContentHeight(preferredContentHeight, animate: false)
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
        panel.minSize = NSSize(width: 350, height: DashboardSizing.minimumHeight)
        panel.maxSize = NSSize(width: 560, height: DashboardSizing.maximumHeight)
        panel.delegate = self
        panel.contentView = NSHostingView(
            rootView: DashboardView(model: model) { [weak self] preferredHeight in
                Task { @MainActor [weak self] in
                    self?.resizeForContentHeight(preferredHeight)
                }
            }
        )
        panel.center()
        self.panel = panel
        return panel
    }

    private func applyPinned(_ isPinned: Bool) {
        panel?.level = isPinned ? .floating : .normal
    }

    private func resizeForContentHeight(
        _ contentHeight: CGFloat,
        animate: Bool = true
    ) {
        guard let panel else { return }
        preferredContentHeight = contentHeight
        let availableHeight = (panel.screen ?? NSScreen.main)?.visibleFrame.height
            ?? DashboardSizing.maximumHeight
        let targetHeight = DashboardSizing.panelHeight(
            contentHeight: contentHeight,
            availableScreenHeight: availableHeight
        )
        guard abs(panel.frame.height - targetHeight) >= 0.5 else { return }

        setPanelHeight(
            panel,
            targetHeight: targetHeight,
            preferredTop: panel.frame.maxY,
            animate: animate && panel.isVisible
        )
    }

    private func setPanelHeight(
        _ panel: NSPanel,
        targetHeight: CGFloat,
        preferredTop: CGFloat,
        animate: Bool
    ) {
        let visibleFrame = (panel.screen ?? NSScreen.main)?.visibleFrame
        let screenMaximum = visibleFrame?.height ?? panel.maxSize.height
        let maximumHeight = min(panel.maxSize.height, screenMaximum)
        let height = min(max(targetHeight, panel.minSize.height), maximumHeight)

        var frame = panel.frame
        frame.size.height = height
        frame.origin.y = preferredTop - height

        if let visibleFrame {
            frame.origin.y = min(
                max(frame.origin.y, visibleFrame.minY),
                visibleFrame.maxY - height
            )
        }

        panel.setFrame(frame, display: true, animate: animate)
    }
}
