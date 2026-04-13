import ComposableArchitecture
import Foundation
import SwiftData

// MARK: - Glow Local Client

struct GlowLocalClient: Sendable {
    var getTodayChallenge: @Sendable () async throws -> ChallengeSnapshot?
    var saveChallenge: @Sendable (ChallengeSnapshot) async throws -> Void
    var completeChallenge: @Sendable (
        _ id: UUID, _ photoData: Data, _ thumbnail: Data,
        _ rating: String, _ feedback: String, _ xpEarned: Int
    ) async throws -> Void
    var skipChallenge: @Sendable (_ id: UUID) async throws -> Void
    var getProfile: @Sendable () async throws -> GlowProfileSnapshot
    /// Returns (previous, updated). `rating` updates gold/silver/bronze counts.
    var addXP: @Sendable (_ amount: Int, _ rating: String) async throws -> (
        previous: GlowProfileSnapshot, current: GlowProfileSnapshot
    )
    var getRecentCompletedTemplateIds: @Sendable (_ days: Int) async throws -> [String]
}

// MARK: - Dependency

extension GlowLocalClient: DependencyKey {
    static let liveValue = GlowLocalClient.live()
    static let testValue = GlowLocalClient.mock()
    static let previewValue = GlowLocalClient.mock()
}

extension DependencyValues {
    var glowLocal: GlowLocalClient {
        get { self[GlowLocalClient.self] }
        set { self[GlowLocalClient.self] = newValue }
    }
}

// MARK: - Live

extension GlowLocalClient {
    static func live() -> Self {
        GlowLocalClient(
            getTodayChallenge: {
                let context = ModelContext(CycleDataStore.shared)
                let startOfDay = Calendar.current.startOfDay(for: Date())
                let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
                let predicate = #Predicate<ChallengeRecord> { record in
                    record.date >= startOfDay && record.date < endOfDay
                }
                var descriptor = FetchDescriptor(predicate: predicate)
                descriptor.fetchLimit = 1
                guard let record = try context.fetch(descriptor).first else { return nil }
                return ChallengeSnapshot(record: record)
            },

            saveChallenge: { snapshot in
                let context = ModelContext(CycleDataStore.shared)
                let record = ChallengeRecord(
                    templateId: snapshot.templateId,
                    challengeCategory: snapshot.challengeCategory,
                    challengeTitle: snapshot.challengeTitle,
                    challengeDescription: snapshot.challengeDescription,
                    tips: (try? String(data: JSONEncoder().encode(snapshot.tips), encoding: .utf8)) ?? "[]",
                    goldHint: snapshot.goldHint,
                    validationPrompt: snapshot.validationPrompt,
                    cyclePhase: snapshot.cyclePhase,
                    cycleDay: snapshot.cycleDay,
                    energyLevel: snapshot.energyLevel
                )
                record.id = snapshot.id
                record.date = snapshot.date
                context.insert(record)
                try context.save()
            },

            completeChallenge: { id, photoData, thumbnail, rating, feedback, xpEarned in
                let context = ModelContext(CycleDataStore.shared)
                let predicate = #Predicate<ChallengeRecord> { $0.id == id }
                var descriptor = FetchDescriptor(predicate: predicate)
                descriptor.fetchLimit = 1
                guard let record = try context.fetch(descriptor).first else { return }
                record.status = "completed"
                record.completedAt = Date()
                record.photoData = photoData
                record.photoThumbnail = thumbnail
                record.validationRating = rating
                record.validationFeedback = feedback
                record.xpEarned = xpEarned
                try context.save()
            },

            skipChallenge: { id in
                let context = ModelContext(CycleDataStore.shared)
                let predicate = #Predicate<ChallengeRecord> { $0.id == id }
                var descriptor = FetchDescriptor(predicate: predicate)
                descriptor.fetchLimit = 1
                guard let record = try context.fetch(descriptor).first else { return }
                record.status = "skipped"
                try context.save()
            },

            getProfile: {
                let context = ModelContext(CycleDataStore.shared)
                let descriptor = FetchDescriptor<GlowProfileRecord>()
                if let record = try context.fetch(descriptor).first {
                    return GlowProfileSnapshot(record: record)
                }
                let record = GlowProfileRecord()
                context.insert(record)
                try context.save()
                return GlowProfileSnapshot(record: record)
            },

            addXP: { amount, rating in
                let context = ModelContext(CycleDataStore.shared)
                let descriptor = FetchDescriptor<GlowProfileRecord>()
                let record: GlowProfileRecord
                if let existing = try context.fetch(descriptor).first {
                    record = existing
                } else {
                    record = GlowProfileRecord()
                    context.insert(record)
                }

                let previous = GlowProfileSnapshot(record: record)

                // Update consistency
                if let lastDate = record.lastCompletedDate,
                   Calendar.current.isDateInYesterday(lastDate)
                {
                    record.currentConsistencyDays += 1
                } else {
                    record.currentConsistencyDays = 1
                }

                // Calculate bonus
                let bonus: Int
                if record.currentConsistencyDays >= 7 {
                    bonus = GlowConstants.consistencyBonus7Days
                } else if record.currentConsistencyDays >= 3 {
                    bonus = GlowConstants.consistencyBonus3Days
                } else {
                    bonus = 0
                }

                // Update totals
                record.totalXP += amount + bonus
                record.totalCompleted += 1
                record.lastCompletedDate = Date()
                record.longestConsistencyDays = max(
                    record.longestConsistencyDays,
                    record.currentConsistencyDays
                )

                // Update rating counts
                switch rating {
                case "gold": record.goldCount += 1
                case "silver": record.silverCount += 1
                case "bronze": record.bronzeCount += 1
                default: break
                }

                // Recalculate level
                record.currentLevel = GlowConstants.levelFor(xp: record.totalXP).level

                try context.save()
                let current = GlowProfileSnapshot(record: record)
                return (previous, current)
            },

            getRecentCompletedTemplateIds: { days in
                let context = ModelContext(CycleDataStore.shared)
                let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
                let predicate = #Predicate<ChallengeRecord> { record in
                    record.status == "completed" && record.date >= cutoff
                }
                let descriptor = FetchDescriptor(predicate: predicate)
                let records = try context.fetch(descriptor)
                return records.map(\.templateId)
            }
        )
    }
}

// MARK: - Mock

extension GlowLocalClient {
    static func mock() -> Self {
        GlowLocalClient(
            getTodayChallenge: { nil },
            saveChallenge: { _ in },
            completeChallenge: { _, _, _, _, _, _ in },
            skipChallenge: { _ in },
            getProfile: { .empty },
            addXP: { _, _ in (.empty, .empty) },
            getRecentCompletedTemplateIds: { _ in [] }
        )
    }
}
