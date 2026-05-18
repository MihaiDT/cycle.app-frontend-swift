import Combine
import Foundation
import SwiftUI

// MARK: - Tracking Preferences
//
// User-controlled visibility + ordering for the symptom-sheet
// categories. Persisted in UserDefaults so the choice survives
// across launches without touching SwiftData (no health data
// here, just UI preferences).
//
// Default: every category enabled, in the canonical
// `SymptomCategory.allCases` order. New categories added later
// auto-appear at the end of the user's order.

enum TrackingPreferencesKeys {
    static let orderJSON = "cycle.app.tracking.categoryOrder"
    static let disabledJSON = "cycle.app.tracking.categoryDisabled"
}

@MainActor
final class TrackingPreferencesStore: ObservableObject {
    static let shared = TrackingPreferencesStore()

    @Published private(set) var order: [SymptomCategory]
    @Published private(set) var disabled: Set<SymptomCategory>

    private init() {
        self.order = Self.loadOrder()
        self.disabled = Self.loadDisabled()
    }

    // MARK: - Derived

    var orderedEnabledCategories: [SymptomCategory] {
        order.filter { !disabled.contains($0) }
    }

    var allEnabled: Bool {
        disabled.isEmpty
    }

    func isEnabled(_ category: SymptomCategory) -> Bool {
        !disabled.contains(category)
    }

    // MARK: - Mutations

    func setOrder(_ newOrder: [SymptomCategory]) {
        order = newOrder
        let raws = newOrder.map { $0.rawValue }
        persist(raws, key: TrackingPreferencesKeys.orderJSON)
    }

    func setEnabled(_ category: SymptomCategory, _ enabled: Bool) {
        if enabled {
            disabled.remove(category)
        } else {
            disabled.insert(category)
        }
        let raws = disabled.map { $0.rawValue }
        persist(raws, key: TrackingPreferencesKeys.disabledJSON)
    }

    func setAllEnabled(_ enabled: Bool) {
        if enabled {
            disabled.removeAll()
        } else {
            disabled = Set(SymptomCategory.allCases)
        }
        let raws = disabled.map { $0.rawValue }
        persist(raws, key: TrackingPreferencesKeys.disabledJSON)
    }

    // MARK: - Persistence

    private func persist(_ values: [String], key: String) {
        guard let data = try? JSONEncoder().encode(values),
              let json = String(data: data, encoding: .utf8) else { return }
        UserDefaults.standard.set(json, forKey: key)
    }

    private static func loadOrder() -> [SymptomCategory] {
        var ordered: [SymptomCategory] = []
        if let json = UserDefaults.standard.string(forKey: TrackingPreferencesKeys.orderJSON),
           let data = json.data(using: .utf8),
           let raws = try? JSONDecoder().decode([String].self, from: data) {
            for raw in raws {
                if let cat = SymptomCategory(rawValue: raw), !ordered.contains(cat) {
                    ordered.append(cat)
                }
            }
        }
        // Append any newly-added categories not yet in the persisted order.
        for cat in SymptomCategory.allCases where !ordered.contains(cat) {
            ordered.append(cat)
        }
        return ordered
    }

    private static func loadDisabled() -> Set<SymptomCategory> {
        guard let json = UserDefaults.standard.string(forKey: TrackingPreferencesKeys.disabledJSON),
              let data = json.data(using: .utf8),
              let raws = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return Set(raws.compactMap { SymptomCategory(rawValue: $0) })
    }
}

