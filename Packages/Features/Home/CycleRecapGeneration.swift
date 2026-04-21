import Foundation
import SwiftData

// MARK: - Recap AI Generation + Caching
//
// The recap pipeline runs in three steps for a given cycle:
//   1. Extract structured Key Days via `KeyDayExtractor` (deterministic).
//   2. Call the backend AI to generate 6 chapters of narrative, passing
//      the Key Days as context so the story references real data.
//   3. On failure, fall back to a template recap that uses the same Key
//      Days + cycle stats.
// Results are cached per cycle in `CycleRecapRecord`.

extension CycleJourneyFeature {

    static let recapURL = "https://dth-backend-277319586889.us-central1.run.app/api/cycle-recap"

    static let dateKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func dateKey(_ date: Date) -> String {
        dateKeyFormatter.string(from: date)
    }

    // MARK: Cache

    /// Load cached recap. `maxAge` in seconds — nil means no expiry.
    /// Returns nil when the cached record was written before the
    /// 6-chapter refactor (detected via empty `chapterTheme`).
    static func loadCachedRecap(cycleStart: Date, maxAge: TimeInterval? = nil) -> RecapData? {
        let container = CycleDataStore.shared
        let context = ModelContext(container)
        let key = dateKey(cycleStart)
        let descriptor = FetchDescriptor<CycleRecapRecord>(
            predicate: #Predicate { $0.cycleKey == key }
        )
        guard let record = try? context.fetch(descriptor).first else { return nil }

        // Stale pre-6-chapter cache — force regeneration.
        if record.chapterTheme.isEmpty { return nil }

        if let maxAge, Date.now.timeIntervalSince(record.createdAt) > maxAge {
            context.delete(record)
            try? context.save()
            return nil
        }

        let keyDays = decodeKeyDays(record.chapterKeyDaysJSON)
        return RecapData(
            headline: record.headline,
            cycleVibe: record.cycleVibe,
            themeText: record.chapterTheme,
            bodyText: record.chapterBody,
            heartMindText: record.chapterMind,
            rhythmText: record.chapterPattern,
            keyDays: keyDays,
            whatsComingText: record.chapterWhatsComing
        )
    }

    static func cacheRecap(_ data: RecapData, cycleStart: Date) {
        let container = CycleDataStore.shared
        let context = ModelContext(container)
        let key = dateKey(cycleStart)

        let descriptor = FetchDescriptor<CycleRecapRecord>(
            predicate: #Predicate { $0.cycleKey == key }
        )
        if let existing = try? context.fetch(descriptor) {
            for r in existing { context.delete(r) }
        }

        let record = CycleRecapRecord(
            cycleKey: key,
            chapterTheme: data.themeText,
            chapterBody: data.bodyText,
            chapterMind: data.heartMindText,
            chapterPattern: data.rhythmText,
            chapterKeyDaysJSON: encodeKeyDays(data.keyDays),
            chapterWhatsComing: data.whatsComingText,
            headline: data.headline,
            cycleVibe: data.cycleVibe
        )
        context.insert(record)
        try? context.save()
    }

    /// One-time cleanup: remove legacy UserDefaults keys from old recap banner system.
    static func cleanupLegacyRecapDefaults() {
        let keys = ["NewRecapCycleKey", "NewRecapMonthName", "LastDismissedRecapKey"]
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private static func encodeKeyDays(_ days: [KeyDay]) -> String {
        let payload = days.map(KeyDayDTO.init(from:))
        guard let data = try? JSONEncoder().encode(payload),
              let string = String(data: data, encoding: .utf8)
        else { return "" }
        return string
    }

    private static func decodeKeyDays(_ json: String) -> [KeyDay] {
        guard let data = json.data(using: .utf8),
              let dtos = try? JSONDecoder().decode([KeyDayDTO].self, from: data)
        else { return [] }
        return dtos.map { $0.toModel() }
    }

    // MARK: AI Fetch

    static func fetchRecapAI(
        summary: JourneyCycleSummary,
        allSummaries: [JourneyCycleSummary],
        keyDays: [KeyDay],
        moments: [MomentSummary]
    ) async -> RecapData? {
        let completed = allSummaries.filter { !$0.isCurrentCycle }
        let avgLength = completed.isEmpty
            ? Double(summary.cycleLength)
            : Double(completed.map(\.cycleLength).reduce(0, +)) / Double(completed.count)
        let prevLengths = completed.map(\.cycleLength)
        let bd = summary.phaseBreakdown

        let keyDaysContext = keyDays.map { key -> String in
            let reasons = key.reasons.map(\.rawValue).joined(separator: ", ")
            var line = "Day \(key.day) (\(key.phase.displayName.lowercased())"
            if let hbi = key.hbi { line += ", HBI \(hbi)" }
            if let mood = key.mood { line += ", mood \(mood)/5" }
            if let energy = key.energy { line += ", energy \(energy)/5" }
            line += "): \(reasons)"
            if let cat = key.momentCategory { line += " — moment: \(cat)" }
            return "- " + line
        }.joined(separator: "\n")

        let momentsContext = moments.map { m -> String in
            "- Day \(m.day): \(m.category)"
        }.joined(separator: "\n")

        let prompt = """
        You are a warm and intuitive wellness companion. You speak like a wise, \
        caring friend — never clinical, always personal. You notice patterns others \
        miss and frame insights in ways that make women feel truly seen.

        Write a personalized 6-chapter cycle recap. Each chapter should feel like \
        a different revelation — not repetitive, not generic. Reference the Key \
        Days where natural. Never mention astrology, charts, transits, or any \
        gamification labels (medals, ratings, points).

        CYCLE DATA:
        - Cycle #\(summary.cycleNumber)
        - Length: \(summary.cycleLength) days (average: \(String(format: "%.0f", avgLength)) days)
        - Period: \(summary.bleedingDays) days of bleeding
        - Phases: Menstrual \(bd.menstrualDays)d, Follicular \(bd.follicularDays)d, Ovulatory \(bd.ovulatoryDays)d, Luteal \(bd.lutealDays)d
        - Energy: \(summary.avgEnergy.map { String(format: "%.1f", $0) + "/5" } ?? "not tracked")
        - Mood: \(summary.avgMood.map { String(format: "%.1f", $0) + "/5" } ?? "not tracked")
        - Prediction accuracy: \(summary.accuracyLabel ?? "no prediction")
        - Previous cycle lengths: \(prevLengths)
        - In progress: \(summary.isCurrentCycle ? "yes" : "no")

        KEY DAYS (selected by our engine — write a short 1-2 sentence narrative per day):
        \(keyDaysContext.isEmpty ? "- none this cycle" : keyDaysContext)

        MOMENTS THIS CYCLE:
        \(momentsContext.isEmpty ? "- none logged" : momentsContext)

        Respond with ONLY valid JSON (no markdown, no code fences):
        {
          "headline": "3-5 word title",
          "cycle_vibe": "one word",
          "theme": "2-3 sentences for Chapter 1 (the throughline of the cycle)",
          "body": "2-3 sentences for Chapter 2 (how the body moved through this cycle)",
          "heart_and_mind": "2-3 sentences for Chapter 3 (emotional story)",
          "rhythm": "2-3 sentences for Chapter 4 (cross-cycle pattern, if any)",
          "key_day_narratives": [ { "day": <Int>, "text": "1-2 sentences" } ],
          "whats_coming": "2-3 sentences for Chapter 6 (what the next cycle might bring)"
        }

        RULES:
        - Use "you" and "your" — speak directly to her
        - Weave numbers naturally; never list stats
        - Each chapter reveals something different
        - If mood/energy not tracked, encourage check-ins warmly
        - No emojis, no exclamation marks
        - Max 3 sentences per chapter, max 2 per key day narrative
        """

        let payload: [String: Any] = [
            "prompt": prompt,
            "cycle_number": summary.cycleNumber,
            "cycle_length": summary.cycleLength,
            "bleeding_days": summary.bleedingDays,
            "avg_cycle_length": Int(avgLength.rounded()),
            "has_mood_data": summary.avgMood != nil,
        ]

        guard let url = URL(string: recapURL),
              let body = try? JSONSerialization.data(withJSONObject: payload)
        else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResp = response as? HTTPURLResponse,
              httpResp.statusCode == 200
        else { return nil }

        struct AIRecapResponse: Decodable {
            struct KeyDayNarrative: Decodable {
                let day: Int
                let text: String
            }
            let headline: String
            let cycle_vibe: String
            let theme: String
            let body: String
            let heart_and_mind: String
            let rhythm: String
            let key_day_narratives: [KeyDayNarrative]?
            let whats_coming: String
        }

        guard let ai = try? JSONDecoder().decode(AIRecapResponse.self, from: data) else { return nil }

        // Merge AI narratives into structured KeyDays; fall back to the
        // template narrative when the AI skipped or mislabeled a day.
        let narrativeByDay: [Int: String] = Dictionary(
            uniqueKeysWithValues: (ai.key_day_narratives ?? []).map { ($0.day, $0.text) }
        )
        let enrichedKeyDays = keyDays.map { key in
            KeyDay(
                id: key.id,
                day: key.day,
                phase: key.phase,
                hbi: key.hbi,
                mood: key.mood,
                energy: key.energy,
                reasons: key.reasons,
                narrative: narrativeByDay[key.day] ?? key.narrative,
                momentCategory: key.momentCategory
            )
        }

        return RecapData(
            headline: ai.headline,
            cycleVibe: ai.cycle_vibe,
            themeText: ai.theme,
            bodyText: ai.body,
            heartMindText: ai.heart_and_mind,
            rhythmText: ai.rhythm,
            keyDays: enrichedKeyDays,
            whatsComingText: ai.whats_coming
        )
    }

    // MARK: Template Fallback

    static func templateRecap(
        summary: JourneyCycleSummary,
        allSummaries: [JourneyCycleSummary],
        keyDays: [KeyDay]
    ) -> RecapData {
        let completed = allSummaries.filter { !$0.isCurrentCycle }
        let avgLength = completed.isEmpty
            ? Double(summary.cycleLength)
            : Double(completed.map(\.cycleLength).reduce(0, +)) / Double(completed.count)
        let diff = summary.cycleLength - Int(avgLength.rounded())
        let bd = summary.phaseBreakdown

        // Ch1 Theme
        let theme: String
        if summary.isCurrentCycle {
            theme = "This cycle is still unfolding. What you do today becomes part of the story you'll read at the end."
        } else if abs(diff) <= 1 {
            theme = "Your body kept to its own tempo this cycle. A steady chapter — and those matter more than they seem."
        } else if diff > 0 {
            theme = "This cycle stretched longer than your usual rhythm. Something was being processed underneath — your body took the time it needed."
        } else {
            theme = "A swifter cycle than usual. Your body moved through its arc at its own pace."
        }

        // Ch2 Body
        var bodyText = "Your period lasted \(summary.bleedingDays) days, followed by \(bd.follicularDays) days where energy typically rebuilds."
        if let energy = summary.avgEnergy {
            let word = energy >= 4 ? "high" : energy >= 3 ? "steady" : "gentler"
            bodyText += " Your energy ran \(word) this cycle — \(String(format: "%.1f", energy)) out of 5 on average."
        } else {
            bodyText += " Track your energy next cycle to see how your body moves through each phase."
        }

        // Ch3 Heart & Mind
        let heartMind: String
        if let mood = summary.avgMood {
            let word = mood >= 4 ? "bright" : mood >= 3 ? "balanced" : "quieter"
            heartMind = "Your inner weather was \(word) this cycle, averaging \(String(format: "%.1f", mood)) out of 5. Every cycle teaches you something about your own rhythms."
        } else {
            heartMind = "Your emotional story this cycle is still unwritten. A daily check-in takes a moment and reveals patterns that might surprise you."
        }

        // Ch4 Rhythm
        let rhythm: String
        if completed.count >= 2 {
            let lengths = completed.map(\.cycleLength)
            let shortest = lengths.min() ?? 0
            let longest = lengths.max() ?? 0
            var sentence = "Across \(completed.count) cycles, your rhythm ranges from \(shortest) to \(longest) days."
            if abs(diff) <= 2 {
                sentence += " This cycle fits right in."
            } else {
                sentence += " Variation is natural — each cycle adds to your signature."
            }
            rhythm = sentence
        } else {
            rhythm = "You're still building your pattern. By your third cycle, the rhythm that's uniquely yours will start to show."
        }

        // Ch6 What's Coming — phase-aware soft preview
        let whatsComing: String
        if summary.isCurrentCycle {
            whatsComing = "Once this cycle closes, you'll see how it compares to the ones before. Keep tracking — the story is building."
        } else {
            whatsComing = "Next cycle, watch for your ovulatory peak around day \(max(1, Int(avgLength.rounded()) - 14)). Plan something for that window — your energy will be ready."
        }

        // Ch5 Key Days already have template narratives from the extractor.

        let headline: String
        let vibe: String
        if summary.isCurrentCycle {
            headline = "Still unfolding"
            vibe = "Present"
        } else if abs(diff) <= 1 {
            headline = "Right on rhythm"
            vibe = "Steady"
        } else if diff > 2 {
            headline = "A longer chapter"
            vibe = "Shifting"
        } else if diff < -2 {
            headline = "Moving quickly"
            vibe = "Swift"
        } else {
            headline = "Another chapter"
            vibe = "Grounded"
        }

        return RecapData(
            headline: headline,
            cycleVibe: vibe,
            themeText: theme,
            bodyText: bodyText,
            heartMindText: heartMind,
            rhythmText: rhythm,
            keyDays: keyDays,
            whatsComingText: whatsComing
        )
    }
}

// MARK: - Persistence-side DTOs

/// Moment logged within a cycle. Surface contract for the AI prompt —
/// kept separate from `KeyDay` because not every moment is a key day.
public struct MomentSummary: Equatable, Sendable {
    public let day: Int
    public let category: String

    public init(day: Int, category: String) {
        self.day = day
        self.category = category
    }
}

/// JSON-friendly projection of `KeyDay` used for cache serialization.
private struct KeyDayDTO: Codable {
    let id: UUID
    let day: Int
    let phase: String
    let hbi: Int?
    let mood: Int?
    let energy: Int?
    let reasons: [String]
    let narrative: String
    let momentCategory: String?

    init(from model: KeyDay) {
        self.id = model.id
        self.day = model.day
        self.phase = model.phase.rawValue
        self.hbi = model.hbi
        self.mood = model.mood
        self.energy = model.energy
        self.reasons = model.reasons.map(\.rawValue)
        self.narrative = model.narrative
        self.momentCategory = model.momentCategory
    }

    func toModel() -> KeyDay {
        KeyDay(
            id: id,
            day: day,
            phase: CyclePhase(rawValue: phase) ?? .menstrual,
            hbi: hbi,
            mood: mood,
            energy: energy,
            reasons: reasons.compactMap(KeyDay.Reason.init(rawValue:)),
            narrative: narrative,
            momentCategory: momentCategory
        )
    }
}

// MARK: - Background Recap Generator

enum CycleRecapGenerator {

    static func generateForClosedCycle(_ closedCycleStart: Date) async {
        if CycleJourneyFeature.loadCachedRecap(cycleStart: closedCycleStart) != nil { return }

        do {
            let data = try await MenstrualLocalClient.liveJourneyData()()
            let summaries = CycleJourneyEngine.buildSummaries(
                inputs: data.records,
                reports: data.reports,
                profileAvgCycleLength: data.profileAvgCycleLength,
                profileAvgBleedingDays: data.profileAvgBleedingDays,
                currentCycleStartDate: data.currentCycleStartDate
            )
            let cal = Calendar.current
            guard let summary = summaries.first(where: {
                cal.isDate($0.startDate, inSameDayAs: closedCycleStart)
            }) else { return }

            await generateAndCache(summary: summary, allSummaries: summaries)
        } catch {}
    }

    static func generateMissing() async {
        do {
            let data = try await MenstrualLocalClient.liveJourneyData()()
            let summaries = CycleJourneyEngine.buildSummaries(
                inputs: data.records,
                reports: data.reports,
                profileAvgCycleLength: data.profileAvgCycleLength,
                profileAvgBleedingDays: data.profileAvgBleedingDays,
                currentCycleStartDate: data.currentCycleStartDate
            )
            await preGenerateAll(summaries: summaries)
        } catch { }
    }

    static func preGenerateAll(summaries: [JourneyCycleSummary]) async {
        for summary in summaries {
            guard !summary.isCurrentCycle else { continue }
            if CycleJourneyFeature.loadCachedRecap(cycleStart: summary.startDate) != nil {
                continue
            }
            await generateAndCache(summary: summary, allSummaries: summaries)
        }
    }

    // MARK: - Internal

    private static func generateAndCache(
        summary: JourneyCycleSummary,
        allSummaries: [JourneyCycleSummary]
    ) async {
        let keyDays = extractKeyDays(for: summary)
        let moments = collectMoments(for: summary)

        if let ai = await CycleJourneyFeature.fetchRecapAI(
            summary: summary,
            allSummaries: allSummaries,
            keyDays: keyDays,
            moments: moments
        ) {
            CycleJourneyFeature.cacheRecap(ai, cycleStart: summary.startDate)
            return
        }

        // AI failed — cache the deterministic template so the user still
        // gets a story. Template can be overwritten on next successful AI
        // pass by clearing the record.
        let fallback = CycleJourneyFeature.templateRecap(
            summary: summary,
            allSummaries: allSummaries,
            keyDays: keyDays
        )
        CycleJourneyFeature.cacheRecap(fallback, cycleStart: summary.startDate)
    }

    // MARK: - Signal loading

    private static func extractKeyDays(for summary: JourneyCycleSummary) -> [KeyDay] {
        let context = ModelContext(CycleDataStore.shared)
        let cal = Calendar.current
        let cycleStart = cal.startOfDay(for: summary.startDate)
        guard let cycleEnd = cal.date(byAdding: .day, value: summary.cycleLength, to: cycleStart) else {
            return []
        }

        // Fetch all records for this cycle's date range in one pass.
        let hbiDesc = FetchDescriptor<HBIScoreRecord>(
            predicate: #Predicate { $0.scoreDate >= cycleStart && $0.scoreDate < cycleEnd }
        )
        let reportDesc = FetchDescriptor<SelfReportRecord>(
            predicate: #Predicate { $0.reportDate >= cycleStart && $0.reportDate < cycleEnd }
        )
        let challengeDesc = FetchDescriptor<ChallengeRecord>(
            predicate: #Predicate { $0.date >= cycleStart && $0.date < cycleEnd && $0.status == "completed" }
        )

        let hbis = (try? context.fetch(hbiDesc)) ?? []
        let reports = (try? context.fetch(reportDesc)) ?? []
        let challenges = (try? context.fetch(challengeDesc)) ?? []

        var signals: [KeyDaySignal] = []
        for day in 1...summary.cycleLength {
            guard let date = cal.date(byAdding: .day, value: day - 1, to: cycleStart) else { continue }
            let dayStart = cal.startOfDay(for: date)

            let hbi = hbis.first { cal.isDate($0.scoreDate, inSameDayAs: dayStart) }
                .map { Int($0.hbiAdjusted.rounded()) }
            let report = reports.first { cal.isDate($0.reportDate, inSameDayAs: dayStart) }
            let challenge = challenges.first { cal.isDate($0.date, inSameDayAs: dayStart) }

            // Skip untracked days — no HBI and no report and no challenge
            // means there's nothing to score against.
            if hbi == nil, report == nil, challenge == nil { continue }

            signals.append(KeyDaySignal(
                day: day,
                hbi: hbi,
                mood: report?.moodLevel,
                energy: report?.energyLevel,
                stress: report?.stressLevel,
                sleep: report?.sleepQuality,
                momentCategory: challenge?.challengeCategory
            ))
        }

        return KeyDayExtractor.extract(
            signals: signals,
            cycleLength: summary.cycleLength,
            bleedingDays: summary.bleedingDays
        )
    }

    private static func collectMoments(for summary: JourneyCycleSummary) -> [MomentSummary] {
        let context = ModelContext(CycleDataStore.shared)
        let cal = Calendar.current
        let cycleStart = cal.startOfDay(for: summary.startDate)
        guard let cycleEnd = cal.date(byAdding: .day, value: summary.cycleLength, to: cycleStart) else {
            return []
        }
        let desc = FetchDescriptor<ChallengeRecord>(
            predicate: #Predicate { $0.date >= cycleStart && $0.date < cycleEnd && $0.status == "completed" }
        )
        let records = (try? context.fetch(desc)) ?? []
        return records.compactMap { record -> MomentSummary? in
            let startOfDay = cal.startOfDay(for: record.date)
            let diff = cal.dateComponents([.day], from: cycleStart, to: startOfDay).day ?? 0
            let day = diff + 1
            guard day >= 1, day <= summary.cycleLength else { return nil }
            return MomentSummary(day: day, category: record.challengeCategory)
        }
    }
}
