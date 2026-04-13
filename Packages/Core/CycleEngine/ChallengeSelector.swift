import Foundation

// MARK: - Challenge Selector

enum ChallengeSelector {
    static func select(
        phase: String,
        energyLevel: Int,
        recentTemplateIds: [String],
        templates: [ChallengeTemplate]
    ) -> ChallengeTemplate? {
        let nonRecent = templates.filter { !recentTemplateIds.contains($0.id) }

        // Phase + energy match
        let phaseAndEnergy = nonRecent.filter { template in
            template.phases.contains(phase)
                && energyLevel >= template.energyMin
                && energyLevel <= template.energyMax
        }
        if let pick = phaseAndEnergy.randomElement() {
            return pick
        }

        // Relax energy — phase only
        let phaseOnly = nonRecent.filter { $0.phases.contains(phase) }
        if let pick = phaseOnly.randomElement() {
            return pick
        }

        // Any non-recent
        if let pick = nonRecent.randomElement() {
            return pick
        }

        // Last resort
        return templates.randomElement()
    }
}
