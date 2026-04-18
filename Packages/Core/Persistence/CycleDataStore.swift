import ComposableArchitecture
import Foundation
import SwiftData

// MARK: - Cycle Data Store

/// Central ModelContainer for all on-device health data.
/// Uses CloudKit with `encryptedValues` — data is E2E encrypted.
/// Only the user's device with their Apple ID can decrypt.
public enum CycleDataStore {

    /// All SwiftData model types managed by this store.
    nonisolated(unsafe) public static let schema = Schema([
        UserProfileRecord.self,
        MenstrualProfileRecord.self,
        CycleRecord.self,
        SymptomRecord.self,
        PredictionRecord.self,
        SelfReportRecord.self,
        HBIScoreRecord.self,
        ChatMessageRecord.self,
        DailyCardRecord.self,
        CycleRecapRecord.self,
        WellnessMessageRecord.self,
        ChallengeRecord.self,
        GlowProfileRecord.self,
    ])

    /// Shared container for the app and TCA dependencies.
    /// Uses CloudKit E2E encryption on device, local-only on simulator/tests.
    nonisolated(unsafe) public static let shared: ModelContainer = {
        let useCloudKit: Bool = {
            #if targetEnvironment(simulator)
            return false
            #else
            return true
            #endif
        }()

        let config = ModelConfiguration(
            "CycleData",
            schema: schema,
            cloudKitDatabase: useCloudKit ? .private("iCloud.app.cycle.ios") : .none
        )
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("CycleDataStore: Failed to create ModelContainer — \(error)")
        }
    }()

    /// In-memory container for unit tests and previews.
    public static func makeTestContainer() -> ModelContainer {
        let configuration = ModelConfiguration(
            "CycleDataTest",
            schema: schema,
            isStoredInMemoryOnly: true
        )
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("CycleDataStore: Failed to create test container — \(error)")
        }
    }
}

// MARK: - TCA Dependency

private enum ModelContainerKey: DependencyKey {
    static let liveValue: ModelContainer = CycleDataStore.shared
    static let testValue: ModelContainer = CycleDataStore.makeTestContainer()
    static let previewValue: ModelContainer = CycleDataStore.makeTestContainer()
}

extension DependencyValues {
    public var modelContainer: ModelContainer {
        get { self[ModelContainerKey.self] }
        set { self[ModelContainerKey.self] = newValue }
    }
}
