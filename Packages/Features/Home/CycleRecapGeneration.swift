import Foundation
import SwiftData

// MARK: - Recap AI Generation + Caching

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
    static func loadCachedRecap(cycleStart: Date, maxAge: TimeInterval? = nil) -> RecapData? {
        let container = CycleDataStore.shared
        let context = ModelContext(container)
        let key = dateKey(cycleStart)
        let descriptor = FetchDescriptor<CycleRecapRecord>(
            predicate: #Predicate { $0.cycleKey == key }
        )
        guard let record = try? context.fetch(descriptor).first else { return nil }
        if let maxAge, Date.now.timeIntervalSince(record.createdAt) > maxAge {
            context.delete(record)
            try? context.save()
            return nil
        }
        return RecapData(
            headline: record.headline,
            cycleVibe: record.cycleVibe,
            overviewText: record.chapterOverview,
            bodyText: record.chapterBody,
            mindText: record.chapterMind,
            patternText: record.chapterPattern
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
            chapterOverview: data.overviewText,
            chapterBody: data.bodyText,
            chapterMind: data.mindText,
            chapterPattern: data.patternText,
            headline: data.headline,
            cycleVibe: data.cycleVibe
        )
        context.insert(record)
        try? context.save()
    }

    // MARK: AI Fetch

    static func fetchRecapAI(
        summary: JourneyCycleSummary,
        allSummaries: [JourneyCycleSummary]
    ) async -> RecapData? {
        let completed = allSummaries.filter { !$0.isCurrentCycle }
        let avgLength = completed.isEmpty
            ? Double(summary.cycleLength)
            : Double(completed.map(\.cycleLength).reduce(0, +)) / Double(completed.count)
        let prevLengths = completed.map(\.cycleLength)
        let bd = summary.phaseBreakdown

        let prompt = """
        You are Aria, a warm and intuitive wellness companion. You speak like a wise, caring friend \
        — never clinical, always personal. You notice patterns others miss and frame insights in ways \
        that make women feel truly seen.

        Generate a personalized cycle recap. Each chapter should feel like a different revelation — \
        not repetitive, not generic.

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

        Respond with ONLY valid JSON (no markdown):
        {"headline":"3-5 word title","cycle_vibe":"One word","chapter_overview":"2-3 sentences","chapter_body":"2-3 sentences","chapter_mind":"2-3 sentences","chapter_pattern":"2-3 sentences"}

        RULES:
        - Use "you" and "your" — speak directly to her
        - Be specific with data, weave numbers naturally into sentences
        - Never list stats — tell a story
        - Each chapter reveals something different
        - If mood/energy not tracked, encourage check-ins warmly
        - No emojis, no exclamation marks
        - Max 3 sentences per chapter
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
            let headline: String
            let cycle_vibe: String
            let chapter_overview: String
            let chapter_body: String
            let chapter_mind: String
            let chapter_pattern: String
        }

        guard let ai = try? JSONDecoder().decode(AIRecapResponse.self, from: data) else { return nil }

        return RecapData(
            headline: ai.headline,
            cycleVibe: ai.cycle_vibe,
            overviewText: ai.chapter_overview,
            bodyText: ai.chapter_body,
            mindText: ai.chapter_mind,
            patternText: ai.chapter_pattern
        )
    }

    // MARK: Template Fallback

    static func templateRecap(
        summary: JourneyCycleSummary,
        allSummaries: [JourneyCycleSummary]
    ) -> RecapData {
        let completed = allSummaries.filter { !$0.isCurrentCycle }
        let avgLength = completed.isEmpty
            ? Double(summary.cycleLength)
            : Double(completed.map(\.cycleLength).reduce(0, +)) / Double(completed.count)
        let diff = summary.cycleLength - Int(avgLength.rounded())
        let bd = summary.phaseBreakdown

        var overview: String
        if summary.isCurrentCycle {
            overview = "You're in the middle of cycle \(summary.cycleNumber) right now."
            overview += " So far it's been tracking close to your \(Int(avgLength.rounded()))-day average."
        } else if abs(diff) <= 1 {
            overview = "This cycle was right on your rhythm at \(summary.cycleLength) days."
            overview += " Your body stayed close to its natural tempo."
        } else if diff > 0 {
            overview = "At \(summary.cycleLength) days, this cycle ran \(diff) days longer than your average."
            overview += " Longer cycles happen — your body adjusts to what life brings."
        } else {
            overview = "A shorter cycle at \(summary.cycleLength) days, \(abs(diff)) under your average."
            overview += " Your body moved at its own pace this time."
        }

        var bodyText = "Your period lasted \(summary.bleedingDays) days, followed by \(bd.follicularDays) days of your follicular phase where energy typically rebuilds."
        if let energy = summary.avgEnergy {
            let word = energy >= 4 ? "high" : energy >= 3 ? "steady" : "lower"
            bodyText += " Your energy ran \(word) this cycle, averaging \(String(format: "%.1f", energy)) out of 5."
        } else {
            bodyText += " Track your energy next cycle to see how your body's rhythm unfolds day by day."
        }

        var mindText: String
        if let mood = summary.avgMood {
            let word = mood >= 4 ? "bright" : mood >= 3 ? "balanced" : "quieter"
            mindText = "Your emotional landscape this cycle was \(word), with an average mood of \(String(format: "%.1f", mood)) out of 5."
            mindText += " Every cycle teaches you something new about your inner rhythms."
        } else {
            mindText = "Your emotional story this cycle is still unwritten."
            mindText += " Daily check-ins take just a moment and reveal patterns that might surprise you. Start next cycle and watch your insights come alive."
        }

        var patternText: String
        if completed.count >= 2 {
            let lengths = completed.map(\.cycleLength)
            let shortest = lengths.min() ?? 0
            let longest = lengths.max() ?? 0
            patternText = "Across \(completed.count) cycles, your rhythm ranges from \(shortest) to \(longest) days."
            if abs(diff) <= 2 {
                patternText += " This cycle fits your pattern beautifully — your body knows its tempo."
            } else {
                patternText += " Variation is natural. Each cycle adds to your unique story."
            }
        } else {
            patternText = "You're building your pattern with each cycle you track."
            patternText += " By your third cycle, the rhythms unique to you will start to emerge."
        }

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
            headline = "Another chapter written"
            vibe = "Grounded"
        }

        return RecapData(
            headline: headline,
            cycleVibe: vibe,
            overviewText: overview,
            bodyText: bodyText,
            mindText: mindText,
            patternText: patternText
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

            if let recap = await CycleJourneyFeature.fetchRecapAI(summary: summary, allSummaries: summaries) {
                CycleJourneyFeature.cacheRecap(recap, cycleStart: closedCycleStart)
            }
        } catch {}
    }

    static func generateMissing() async {
        do {
            let data = try await MenstrualLocalClient.liveJourneyData()()
            print("[RecapGen] loaded \(data.records.count) records, current=\(String(describing: data.currentCycleStartDate))")
            let summaries = CycleJourneyEngine.buildSummaries(
                inputs: data.records,
                reports: data.reports,
                profileAvgCycleLength: data.profileAvgCycleLength,
                profileAvgBleedingDays: data.profileAvgBleedingDays,
                currentCycleStartDate: data.currentCycleStartDate
            )
            print("[RecapGen] summaries=\(summaries.count), past=\(summaries.filter { !$0.isCurrentCycle }.count)")
            await preGenerateAll(summaries: summaries)
        } catch {
            print("[RecapGen] error: \(error)")
        }
    }

    static func preGenerateAll(summaries: [JourneyCycleSummary]) async {
        for summary in summaries {
            guard !summary.isCurrentCycle else {
                print("[RecapGen] skip current \(summary.startDate)")
                continue
            }
            if CycleJourneyFeature.loadCachedRecap(cycleStart: summary.startDate) != nil {
                continue
            }
            print("[RecapGen] fetching AI for \(summary.startDate)...")
            if let recap = await CycleJourneyFeature.fetchRecapAI(summary: summary, allSummaries: summaries) {
                CycleJourneyFeature.cacheRecap(recap, cycleStart: summary.startDate)
                print("[RecapGen] saved \(summary.startDate)")
            } else {
                print("[RecapGen] AI failed for \(summary.startDate)")
            }
        }
    }
}
