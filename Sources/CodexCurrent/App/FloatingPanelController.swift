import AppKit
import Combine
import SwiftUI

@MainActor
final class FloatingPanelController: NSObject, ObservableObject, NSWindowDelegate {
    @Published private(set) var isVisible = false

    private let model: AppModel
    private let presentation = DashboardPresentationState()
    private var panel: NSPanel?
    private var collapsedLayout: DashboardLayoutMeasurement?
    private var expandedLayout: DashboardLayoutMeasurement?
    private var suppressExpandedMeasurements = false
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
        guard let layout = currentLayout else { return }
        resizeForLayout(layout, animate: false)
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
        panel.minSize = NSSize(
            width: 350,
            height: DashboardSizing.expandedMinimumHeight
        )
        panel.maxSize = NSSize(width: 560, height: DashboardSizing.maximumHeight)
        panel.delegate = self
        panel.contentView = NSHostingView(
            rootView: DashboardView(
                model: model,
                presentation: presentation,
                onToggleCollapsed: { [weak self] in
                    self?.toggleDashboardCollapsed()
                }
            ) { [weak self] layout in
                Task { @MainActor [weak self] in
                    self?.resizeForLayout(layout)
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

    private func resizeForLayout(
        _ layout: DashboardLayoutMeasurement,
        animate: Bool = true,
        bypassSuppression: Bool = false
    ) {
        guard let panel else { return }
        if !layout.isCollapsed, suppressExpandedMeasurements, !bypassSuppression {
            return
        }
        if layout.isCollapsed {
            collapsedLayout = layout
        } else {
            expandedLayout = layout
        }
        guard layout.isCollapsed == presentation.isCollapsed else { return }

        let availableHeight = (panel.screen ?? NSScreen.main)?.visibleFrame.height
            ?? DashboardSizing.maximumHeight
        let windowChromeHeight = max(
            panel.frame.height - panel.contentLayoutRect.height,
            0
        )
        let targetHeight = DashboardSizing.panelHeight(
            contentHeight: layout.contentHeight,
            windowChromeHeight: windowChromeHeight,
            availableScreenHeight: availableHeight,
            isCollapsed: layout.isCollapsed
        )
        panel.minSize = NSSize(
            width: panel.minSize.width,
            height: targetHeight
        )
        guard abs(panel.frame.height - targetHeight) >= 0.5 else { return }

        setPanelHeight(
            panel,
            targetHeight: targetHeight,
            preferredTop: panel.frame.maxY,
            animate: animate && panel.isVisible
        )
    }

    private var currentLayout: DashboardLayoutMeasurement? {
        presentation.isCollapsed ? collapsedLayout : expandedLayout
    }

    private func toggleDashboardCollapsed() {
        let isCollapsed = !presentation.isCollapsed
        if isCollapsed {
            suppressExpandedMeasurements = false
            presentation.isCollapsed = true
            applyCollapsedState(true)
        } else {
            presentation.isCollapsed = false
            suppressExpandedMeasurements = true
            applyCollapsedState(false, animate: false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                guard let self, !self.presentation.isCollapsed else { return }
                if let expandedLayout = self.expandedLayout {
                    self.resizeForLayout(
                        expandedLayout,
                        bypassSuppression: true
                    )
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                guard let self, !self.presentation.isCollapsed else { return }
                self.suppressExpandedMeasurements = false
            }
        }
    }

    private func applyCollapsedState(
        _ isCollapsed: Bool,
        animate: Bool = true
    ) {
        let fallbackHeight = DashboardSizing.minimumHeight(isCollapsed: isCollapsed)
        let layout = isCollapsed
            ? collapsedLayout ?? DashboardLayoutMeasurement(
                contentHeight: fallbackHeight,
                isCollapsed: true
            )
            : expandedLayout ?? DashboardLayoutMeasurement(
                contentHeight: fallbackHeight,
                isCollapsed: false
            )
        resizeForLayout(
            layout,
            animate: animate,
            bypassSuppression: true
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
