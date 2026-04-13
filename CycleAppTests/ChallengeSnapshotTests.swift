@testable import CycleApp
import Foundation
import Testing

struct ChallengeSnapshotDisplayTests {
    // Helper to build a minimal ChallengeSnapshot for tests
    private func make(
        category: String = "social",
        energyLevel: Int = 5
    ) -> ChallengeSnapshot {
        ChallengeSnapshot(
            id: UUID(),
            date: Date(),
            templateId: "test",
            challengeCategory: category,
            challengeTitle: "Test",
            challengeDescription: "Test description",
            tips: [],
            goldHint: "",
            validationPrompt: "",
            cyclePhase: "luteal",
            cycleDay: 0,
            energyLevel: energyLevel,
            status: .available,
            completedAt: nil,
            photoThumbnail: nil,
            validationRating: nil,
            validationFeedback: nil,
            xpEarned: 0
        )
    }

    // MARK: - effortDisplay (energyLevel is 1-10)

    @Test
    func testEffortDisplayGentle() {
        #expect(make(energyLevel: 1).effortDisplay == "Gentle")
        #expect(make(energyLevel: 2).effortDisplay == "Gentle")
        #expect(make(energyLevel: 3).effortDisplay == "Gentle")
    }

    @Test
    func testEffortDisplayModerate() {
        #expect(make(energyLevel: 4).effortDisplay == "Moderate")
        #expect(make(energyLevel: 5).effortDisplay == "Moderate")
        #expect(make(energyLevel: 6).effortDisplay == "Moderate")
    }

    @Test
    func testEffortDisplayActive() {
        #expect(make(energyLevel: 7).effortDisplay == "Active")
        #expect(make(energyLevel: 10).effortDisplay == "Active")
    }

    // MARK: - themeDisplay

    @Test
    func testThemeDisplayKnownCategories() {
        #expect(make(category: "social").themeDisplay == "Social")
        #expect(make(category: "mindfulness").themeDisplay == "Mindful")
        #expect(make(category: "movement").themeDisplay == "Movement")
        #expect(make(category: "creative").themeDisplay == "Creative")
        #expect(make(category: "nutrition").themeDisplay == "Nutrition")
        #expect(make(category: "self_care").themeDisplay == "Self care")
    }

    @Test
    func testThemeDisplayCaseInsensitive() {
        #expect(make(category: "SOCIAL").themeDisplay == "Social")
        #expect(make(category: "Self_Care").themeDisplay == "Self care")
    }

    @Test
    func testThemeDisplayFallback() {
        #expect(make(category: "new_unknown").themeDisplay == "New_unknown")
    }

    // MARK: - durationDisplay

    @Test
    func testDurationDisplayByCategory() {
        #expect(make(category: "creative").durationDisplay == "15 min")
        #expect(make(category: "movement").durationDisplay == "10 min")
        #expect(make(category: "social").durationDisplay == "5 min")
        #expect(make(category: "mindfulness").durationDisplay == "5 min")
        #expect(make(category: "self_care").durationDisplay == "5 min")
        #expect(make(category: "nutrition").durationDisplay == "5 min")
    }

    @Test
    func testDurationDisplayUnknownDefaultsToFiveMin() {
        #expect(make(category: "unknown").durationDisplay == "5 min")
    }
}
