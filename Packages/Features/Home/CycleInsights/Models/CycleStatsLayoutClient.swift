import ComposableArchitecture
import Foundation

// MARK: - Cycle Stats Layout Client
//
// TCA dependency that owns the Cycle Stats card layout on disk.
// `load` is called once per screen entry; `save` is invoked with
// the full layout and is fire-and-forget from the caller's point
// of view.
//
// Both operations are failure-tolerant by design: a corrupted or
// missing value must never prevent the user from opening Cycle
// Stats, so we fall back to `CycleStatsLayout.default` on any
// error path.

public struct CycleStatsLayoutClient: Sendable {
    public var load: @Sendable () async -> CycleStatsLayout
    public var save: @Sendable (CycleStatsLayout) async -> Void

    public init(
        load: @escaping @Sendable () async -> CycleStatsLayout,
        save: @escaping @Sendable (CycleStatsLayout) async -> Void
    ) {
        self.load = load
        self.save = save
    }
}

extension CycleStatsLayoutClient: DependencyKey {
    public static let liveValue: CycleStatsLayoutClient = {
        // Storage key. Suffixed with a version tag so we can bump it
        // if the layout schema ever changes in a way `normalize`
        // can't migrate — decoded failures silently fall back to
        // `.default`, which is the right behaviour here.
        let key = "cycleInsights.layout.v1"

        return CycleStatsLayoutClient(
            load: {
                // Read `UserDefaults.standard` inside the closure
                // rather than capturing it: Foundation's `UserDefaults`
                // isn't annotated `Sendable`, and pulling a fresh
                // reference each call keeps us out of the capture
                // rules without giving up thread safety (the
                // framework serialises all access internally).
                guard let data = UserDefaults.standard.data(forKey: key) else {
                    return .default
                }
                guard let decoded = try? JSONDecoder().decode(CycleStatsLayout.self, from: data) else {
                    // A failed decode almost always means an older
                    // build wrote an incompatible shape. Resetting
                    // to default here is preferable to leaving the
                    // user with a half-broken screen.
                    return .default
                }
                return CycleStatsLayout.normalize(decoded)
            },
            save: { layout in
                guard let data = try? JSONEncoder().encode(layout) else { return }
                UserDefaults.standard.set(data, forKey: key)
            }
        )
    }()

    public static let testValue = CycleStatsLayoutClient(
        load: { .default },
        save: { _ in }
    )

    public static let previewValue = testValue
}

extension DependencyValues {
    public var cycleStatsLayoutClient: CycleStatsLayoutClient {
        get { self[CycleStatsLayoutClient.self] }
        set { self[CycleStatsLayoutClient.self] = newValue }
    }
}
