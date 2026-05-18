import Foundation
import SwiftData

// MARK: - Data Exporter
//
// Local-first user data export. Walks every `@Model` type held in
// `CycleDataStore`, serialises each record into a plain `[String:
// Any]` dictionary keyed by stable field names, and produces a
// single JSON blob the user can save or share from
// `DataExportReadyView`.
//
// Design notes:
// - JSON is the GDPR-recommended portable format (Art. 20).
// - Every section is namespaced under its `@Model` type so the
//   payload reads like the SwiftData schema rather than a flat
//   bag of records.
// - Dates are emitted as ISO-8601 strings (UTC) for cross-tool
//   compatibility.
// - We never include Firebase tokens, push tokens, or CloudKit
//   container IDs — only data owned by the user.
// - The exporter is intentionally synchronous on the @MainActor.
//   ModelContext isn't Sendable; running it off-actor would force
//   an Actor isolation dance for a one-shot tap-to-export.

public struct DataExporter {
    public enum SchemaVersion {
        public static let current = "1.0"
    }

    public init() {}

    // MARK: - Entry point

    @MainActor
    public func exportAll(
        appVersion: String,
        buildNumber: String,
        preferences: ExportablePreferences,
        referenceCode: String? = nil
    ) throws -> Data {
        let context = ModelContext(CycleDataStore.shared)

        var payload: [String: Any] = [:]
        payload["manifest"] = makeManifest(
            appVersion: appVersion,
            buildNumber: buildNumber,
            referenceCode: referenceCode
        )
        payload["userProfile"] = try makeUserProfile(context: context)
        payload["menstrualProfile"] = try makeMenstrualProfile(context: context)
        payload["cycles"] = try makeCycles(context: context)
        payload["symptoms"] = try makeSymptoms(context: context)
        payload["predictions"] = try makePredictions(context: context)
        payload["selfReports"] = try makeSelfReports(context: context)
        payload["hbiScores"] = try makeHBIScores(context: context)
        payload["preferences"] = preferences.dictionary

        return try JSONSerialization.data(
            withJSONObject: payload,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
    }

    // MARK: - Manifest

    private func makeManifest(
        appVersion: String,
        buildNumber: String,
        referenceCode: String?
    ) -> [String: Any] {
        var manifest: [String: Any] = [
            "schemaVersion": SchemaVersion.current,
            "appVersion": appVersion,
            "buildNumber": buildNumber,
            "exportedAt": Self.iso8601.string(from: .now),
            "format": "json",
            "encoding": "utf-8",
            "source": "cycleapp-ios",
            "sections": [
                "userProfile",
                "menstrualProfile",
                "cycles",
                "symptoms",
                "predictions",
                "selfReports",
                "hbiScores",
                "preferences",
            ],
        ]
        if let referenceCode {
            manifest["referenceCode"] = referenceCode
        }
        return manifest
    }

    // MARK: - UserProfile

    private func makeUserProfile(context: ModelContext) throws -> [String: Any] {
        let records = try context.fetch(FetchDescriptor<UserProfileRecord>())
        guard let record = records.first else { return [:] }

        return [
            "userName": record.userName,
            "email": record.email ?? NSNull(),
            "birthDate": Self.optionalDate(record.birthDate),
            "birthTime": Self.optionalDate(record.birthTime),
            "birthPlace": record.birthPlace ?? NSNull(),
            "birthPlaceLat": record.birthPlaceLat ?? NSNull(),
            "birthPlaceLng": record.birthPlaceLng ?? NSNull(),
            "birthPlaceTimezone": record.birthPlaceTimezone ?? NSNull(),
            "relationshipStatus": record.relationshipStatus ?? NSNull(),
            "professionalContext": record.professionalContext ?? NSNull(),
            "lifestyleType": record.lifestyleType ?? NSNull(),
            "personalGoals": record.personalGoals,
            "healthDataConsent": record.healthDataConsent,
            "termsConsent": record.termsConsent,
            "notificationsEnabled": record.notificationsEnabled,
            "dailyCheckinHour": record.dailyCheckinHour,
            "dailyCheckinMinute": record.dailyCheckinMinute,
            "createdAt": Self.iso8601.string(from: record.createdAt),
            "updatedAt": Self.iso8601.string(from: record.updatedAt),
        ]
    }

    // MARK: - MenstrualProfile

    private func makeMenstrualProfile(context: ModelContext) throws -> [String: Any] {
        let records = try context.fetch(FetchDescriptor<MenstrualProfileRecord>())
        guard let record = records.first else { return [:] }

        return [
            "avgCycleLength": record.avgCycleLength,
            "avgBleedingDays": record.avgBleedingDays,
            "cycleRegularity": record.cycleRegularity,
            "typicalSymptoms": record.typicalSymptoms,
            "typicalFlowIntensity": record.typicalFlowIntensity ?? NSNull(),
            "usesContraception": record.usesContraception,
            "contraceptionType": record.contraceptionType ?? NSNull(),
            "onboardingCycleLength": record.onboardingCycleLength,
            "useManualCycleLength": record.useManualCycleLength,
            "useManualPeriodLength": record.useManualPeriodLength,
            "showOvulation": record.showOvulation,
            "showFertileWindow": record.showFertileWindow,
            "phaseLutealLength": record.phaseLutealLength,
            "onboardingCompletedAt": Self.optionalDate(record.onboardingCompletedAt),
            "journeyStartDate": Self.optionalDate(record.journeyStartDate),
            "createdAt": Self.iso8601.string(from: record.createdAt),
            "updatedAt": Self.iso8601.string(from: record.updatedAt),
        ]
    }

    // MARK: - Cycles

    private func makeCycles(context: ModelContext) throws -> [[String: Any]] {
        let records = try context.fetch(FetchDescriptor<CycleRecord>(
            sortBy: [SortDescriptor(\.startDate, order: .forward)]
        ))

        return records.map { record in
            [
                "startDate": Self.iso8601.string(from: record.startDate),
                "endDate": Self.optionalDate(record.endDate),
                "bleedingDays": record.bleedingDays ?? NSNull(),
                "flowIntensity": record.flowIntensity ?? NSNull(),
                "notes": record.notes ?? NSNull(),
                "isConfirmed": record.isConfirmed,
                "actualCycleLength": record.actualCycleLength ?? NSNull(),
                "predictedStartDate": Self.optionalDate(record.predictedStartDate),
                "actualDeviationDays": record.actualDeviationDays ?? NSNull(),
                "createdAt": Self.iso8601.string(from: record.createdAt),
            ]
        }
    }

    // MARK: - Symptoms

    private func makeSymptoms(context: ModelContext) throws -> [[String: Any]] {
        let records = try context.fetch(FetchDescriptor<SymptomRecord>(
            sortBy: [SortDescriptor(\.symptomDate, order: .forward)]
        ))

        return records.map { record in
            [
                "symptomDate": Self.iso8601.string(from: record.symptomDate),
                "symptomType": record.symptomType,
                "severity": record.severity,
                "notes": record.notes ?? NSNull(),
                "cycleDay": record.cycleDay ?? NSNull(),
                "createdAt": Self.iso8601.string(from: record.createdAt),
            ]
        }
    }

    // MARK: - Predictions

    private func makePredictions(context: ModelContext) throws -> [[String: Any]] {
        let records = try context.fetch(FetchDescriptor<PredictionRecord>(
            sortBy: [SortDescriptor(\.predictedDate, order: .forward)]
        ))

        return records.map { record in
            [
                "predictedDate": Self.iso8601.string(from: record.predictedDate),
                "rangeStart": Self.iso8601.string(from: record.rangeStart),
                "rangeEnd": Self.iso8601.string(from: record.rangeEnd),
                "algorithmVersion": record.algorithmVersion,
                "basedOnCycles": record.basedOnCycles,
                "fertileWindowStart": Self.optionalDate(record.fertileWindowStart),
                "fertileWindowEnd": Self.optionalDate(record.fertileWindowEnd),
                "ovulationDate": Self.optionalDate(record.ovulationDate),
                "actualStartDate": Self.optionalDate(record.actualStartDate),
                "accuracyDays": record.accuracyDays ?? NSNull(),
                "isConfirmed": record.isConfirmed,
                "createdAt": Self.iso8601.string(from: record.createdAt),
            ]
        }
    }

    // MARK: - SelfReports

    private func makeSelfReports(context: ModelContext) throws -> [[String: Any]] {
        let records = try context.fetch(FetchDescriptor<SelfReportRecord>(
            sortBy: [SortDescriptor(\.reportDate, order: .forward)]
        ))

        return records.map { record in
            [
                "reportDate": Self.iso8601.string(from: record.reportDate),
                "energyLevel": record.energyLevel,
                "stressLevel": record.stressLevel,
                "sleepQuality": record.sleepQuality,
                "moodLevel": record.moodLevel,
                "notes": record.notes ?? NSNull(),
                "createdAt": Self.iso8601.string(from: record.createdAt),
            ]
        }
    }

    // MARK: - HBIScores

    private func makeHBIScores(context: ModelContext) throws -> [[String: Any]] {
        let records = try context.fetch(FetchDescriptor<HBIScoreRecord>(
            sortBy: [SortDescriptor(\.scoreDate, order: .forward)]
        ))

        return records.map { record in
            [
                "scoreDate": Self.iso8601.string(from: record.scoreDate),
                "energyScore": record.energyScore,
                "anxietyScore": record.anxietyScore,
                "sleepScore": record.sleepScore,
                "moodScore": record.moodScore,
                "clarityScore": record.clarityScore ?? NSNull(),
                "hbiRaw": record.hbiRaw,
                "hbiAdjusted": record.hbiAdjusted,
                "cyclePhase": record.cyclePhase ?? NSNull(),
                "cycleDay": record.cycleDay ?? NSNull(),
                "phaseMultiplier": record.phaseMultiplier ?? NSNull(),
                "trendVsBaseline": record.trendVsBaseline ?? NSNull(),
                "trendDirection": record.trendDirection ?? NSNull(),
                "createdAt": Self.iso8601.string(from: record.createdAt),
            ]
        }
    }

    // MARK: - Helpers

    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f
    }()

    private static func optionalDate(_ date: Date?) -> Any {
        date.map { iso8601.string(from: $0) } ?? NSNull()
    }
}

// MARK: - Exportable Preferences
//
// Snapshot of the UserDefaults-backed preferences (tracking
// personalization + settings toggles) the user can carry away
// alongside the SwiftData payload. Built by `DataExportReadyView`
// at the moment of export so the on-disk dict is stable for the
// life of the archive.

public struct ExportablePreferences: Sendable {
    public let dictionary: [String: Any]

    public init(dictionary: [String: Any]) {
        self.dictionary = dictionary
    }

    public static func snapshot() -> ExportablePreferences {
        let defaults = UserDefaults.standard
        var dict: [String: Any] = [:]

        dict["tracking.categoryOrder"] = defaults.string(forKey: "cycle.app.tracking.categoryOrder") ?? NSNull()
        dict["tracking.categoryDisabled"] = defaults.string(forKey: "cycle.app.tracking.categoryDisabled") ?? NSNull()
        dict["settings.biometricUnlockEnabled"] = defaults.bool(forKey: "cycle.app.settings.biometricUnlockEnabled")
        dict["settings.hideWidgetData"] = defaults.bool(forKey: "cycle.app.settings.hideWidgetData")
        dict["symptom.forYouTabEnabled"] = defaults.object(forKey: "cycle.app.symptom.forYouTabEnabled") as? Bool ?? true

        return ExportablePreferences(dictionary: dict)
    }
}
