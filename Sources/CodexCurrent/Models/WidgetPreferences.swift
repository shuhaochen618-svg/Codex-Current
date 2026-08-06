import Combine
import Foundation

@MainActor
final class WidgetPreferences: ObservableObject {
    @Published private(set) var order: [WidgetKind]
    @Published private(set) var hidden: Set<WidgetKind>
    @Published var density: DashboardDensity {
        didSet { save() }
    }
    @Published var isPinned: Bool {
        didSet { save() }
    }

    private let defaults: UserDefaults
    private let key = "dashboard.preferences.v1"

    init(
        defaults: UserDefaults = .standard,
        legacyDefaults: UserDefaults? = UserDefaults(suiteName: "dev.local.codexbar")
    ) {
        self.defaults = defaults
        let currentData = defaults.data(forKey: key)
        let storedData = currentData ?? legacyDefaults?.data(forKey: key)

        if
            let data = storedData,
            let stored = try? JSONDecoder().decode(StoredPreferences.self, from: data)
        {
            let validOrder = stored.order.compactMap(WidgetKind.init(rawValue:))
            let missing = WidgetKind.allCases.filter { !validOrder.contains($0) }
            order = validOrder + missing
            hidden = Set(stored.hidden.compactMap(WidgetKind.init(rawValue:)))
            density = DashboardDensity(rawValue: stored.density) ?? .expanded
            isPinned = stored.isPinned
            if currentData == nil {
                defaults.set(data, forKey: key)
            }
        } else {
            order = WidgetKind.allCases
            hidden = Set([.reset, .usage])
            density = .expanded
            isPinned = true
        }
    }

    var visibleWidgets: [WidgetKind] {
        order.filter { !hidden.contains($0) }
    }

    func setVisible(_ kind: WidgetKind, visible: Bool) {
        if visible {
            hidden.remove(kind)
        } else {
            hidden.insert(kind)
        }
        objectWillChange.send()
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        var updated = order
        updated.move(fromOffsets: source, toOffset: destination)
        order = updated
        save()
    }

    func move(_ kind: WidgetKind, direction: Int) {
        guard let index = order.firstIndex(of: kind) else { return }
        let target = index + direction
        guard order.indices.contains(target) else { return }
        order.swapAt(index, target)
        save()
    }

    private func save() {
        let stored = StoredPreferences(
            order: order.map(\.rawValue),
            hidden: hidden.map(\.rawValue),
            density: density.rawValue,
            isPinned: isPinned
        )
        guard let data = try? JSONEncoder().encode(stored) else { return }
        defaults.set(data, forKey: key)
    }
}

private struct StoredPreferences: Codable {
    let order: [String]
    let hidden: [String]
    let density: String
    let isPinned: Bool
}
