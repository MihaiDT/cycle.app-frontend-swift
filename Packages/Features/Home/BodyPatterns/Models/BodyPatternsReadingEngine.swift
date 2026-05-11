import Foundation

// MARK: - Body Patterns Reading Engine
//
// Pure function generator for `PatternReading` editorials. Two
// entry points:
//
//   • `overviewReading(active:emerging:)` – used by the BodyPatterns
//     root feed. Synthesises a single paragraph across the user's
//     active + emerging patterns. Returns nil when there is no
//     signal to talk about.
//
//   • `patternReading(pattern:metrics:)` – used by PatternDetailScreen.
//     Returns a per-pattern paragraph reading the Highlights tiles
//     (occurrences, most active day, co-occurrence, trend) aloud as
//     a coherent sentence sequence.
//
// Variant strategy:
//   The engine doesn't hold copy strings. All editorial templates
//   live in `BodyPatternsReadingTemplates`. For each scenario the
//   engine picks ONE variant via a deterministic hash of the
//   relevant pattern set – same input → same text within a cycle,
//   different input across cycles → variants rotate naturally.
//
//   The hash is djb2 (stable across launches, unlike Swift's
//   randomised `hashValue`). For detail readings, each component
//   sentence (S1 / S2 / S3 / S4) gets its own offset of the base
//   seed so the components vary independently of each other.
//
// All calls are pure: no SwiftData, no network, no clock. Suitable
// for running inside a TCA reducer or a SwiftUI .task with no
// concurrency ceremony.

enum BodyPatternsReadingEngine {

    // MARK: - Overview reading (BodyPatterns root)

    /// Picks the strongest narrative shape for the user's pattern
    /// set, then renders one variant from the corresponding template
    /// array. Branch order:
    ///   1. Cluster: ≥ 2 active patterns sharing a phase.
    ///   2. Multi-active: ≥ 2 active across multiple phases.
    ///   3. Single active: one rhythm, names it.
    ///   4. Single emerging: one fresh signal.
    ///   5. Multiple emerging.
    ///   6. Empty: returns nil; the host hides the card.
    static func overviewReading(
        active: [DetectedPattern],
        emerging: [DetectedPattern]
    ) -> PatternReading? {
        let seed = stableHash(seedKey(active: active, emerging: emerging))

        if let cluster = phaseCluster(active) {
            let listed = listPhrase(cluster.patterns.map { $0.symptomDisplayName.lowercased() })
            let template = pickVariant(BodyPatternsReadingTemplates.overviewCluster, seed: seed)
            let copy = render(template, with: [
                "{phase}": cluster.phaseName,
                "{list}": listed,
                "{cycles}": "\(cluster.cyclesRunning)"
            ])
            return PatternReading(copy: copy, phase: cluster.phase)
        }

        if active.count >= 2 {
            let groups = Dictionary(grouping: active, by: \.phase)
            if let loudest = groups.max(by: { $0.value.count < $1.value.count }) {
                let phase = loudest.key
                let names = active.map { $0.symptomDisplayName.lowercased() }
                let listed = listPhrase(Array(names.prefix(3)))
                let template = pickVariant(BodyPatternsReadingTemplates.overviewMultiPhase, seed: seed)
                let copy = render(template, with: [
                    "{phase}": phaseDisplayName(phase),
                    "{list}": listed
                ])
                return PatternReading(copy: copy, phase: phase)
            }
        }

        if active.count == 1 {
            let p = active[0]
            let template = pickVariant(BodyPatternsReadingTemplates.overviewSingleActive, seed: seed)
            let copy = render(template, with: [
                "{phase}": phaseDisplayName(p.phase),
                "{name}": p.symptomDisplayName.lowercased(),
                "{cycles}": "\(p.totalCycles)"
            ])
            return PatternReading(copy: copy, phase: p.phase)
        }

        if active.isEmpty, !emerging.isEmpty {
            if emerging.count == 1 {
                let p = emerging[0]
                let template = pickVariant(BodyPatternsReadingTemplates.overviewSingleEmerging, seed: seed)
                let copy = render(template, with: [
                    "{name}": p.symptomDisplayName.lowercased(),
                    "{occurrences}": "\(p.occurrences)"
                ])
                return PatternReading(copy: copy, phase: p.phase)
            } else {
                let names = emerging.map { $0.symptomDisplayName.lowercased() }
                let listed = listPhrase(Array(names.prefix(3)))
                let template = pickVariant(BodyPatternsReadingTemplates.overviewMultiEmerging, seed: seed)
                let copy = render(template, with: ["{list}": listed])
                return PatternReading(copy: copy, phase: emerging.first?.phase)
            }
        }

        return nil
    }

    // MARK: - Pattern reading (PatternDetailScreen)

    /// Reads the per-pattern Highlights aloud as a sentence sequence.
    /// Each sentence component (S1 / S2 / S3 / S4) picks its own
    /// variant from a different template array, with a slightly
    /// offset seed so the components vary independently.
    static func patternReading(
        pattern: DetectedPattern,
        metrics: PatternMetrics
    ) -> PatternReading {
        let baseSeed = stableHash(pattern.symptomTypeRaw + "_c\(pattern.totalCycles)")
        var sentences: [String] = []

        // S1 – occurrences (always)
        sentences.append(render(
            pickVariant(BodyPatternsReadingTemplates.detailOccurrence, seed: baseSeed),
            with: [
                "{name}": pattern.symptomDisplayName.capitalized,
                "{occurrences}": "\(pattern.occurrences)",
                "{total}": "\(pattern.totalCycles)"
            ]
        ))

        // S2 – most active day (when there's a clear winner)
        if let day = metrics.mostActiveDay,
           metrics.mostActiveDayCycleCount >= 2 {
            sentences.append(render(
                pickVariant(BodyPatternsReadingTemplates.detailMostActiveDay, seed: baseSeed &+ 1001),
                with: ["{day}": "\(day)"]
            ))
        }

        // S3 – top co-occurring symptom
        if let coRaw = metrics.coOccurringSymptomRaw,
           metrics.coOccurringSymptomCount >= 2 {
            let coName = formatSymptomRaw(coRaw)
            sentences.append(render(
                pickVariant(BodyPatternsReadingTemplates.detailCoOccurrence, seed: baseSeed &+ 2002),
                with: [
                    "{coname}": coName.capitalized,
                    "{cocount}": "\(metrics.coOccurringSymptomCount)"
                ]
            ))
        }

        // S4 – trend (only when strengthening or easing)
        switch metrics.trend {
        case .easing:
            sentences.append(pickVariant(
                BodyPatternsReadingTemplates.detailTrendEasing,
                seed: baseSeed &+ 3003
            ))
        case .strengthening:
            sentences.append(pickVariant(
                BodyPatternsReadingTemplates.detailTrendStrengthening,
                seed: baseSeed &+ 3003
            ))
        case .persisting, .justAppearing:
            break
        }

        return PatternReading(
            copy: sentences.joined(separator: " "),
            phase: pattern.phase
        )
    }

    // MARK: - Variant picking

    /// Stable djb2 hash. Unlike Swift's `hashValue` (randomised per
    /// process for security), djb2 is deterministic across launches
    /// – required so the same pattern set produces the same text on
    /// every app open within a cycle.
    private static func stableHash(_ s: String) -> Int {
        var hash: UInt32 = 5381
        for byte in s.utf8 {
            hash = hash &* 33 &+ UInt32(byte)
        }
        return Int(hash & 0x7FFFFFFF)
    }

    private static func pickVariant(_ variants: [String], seed: Int) -> String {
        guard !variants.isEmpty else { return "" }
        return variants[abs(seed) % variants.count]
    }

    private static func render(_ template: String, with placeholders: [String: String]) -> String {
        var out = template
        for (key, value) in placeholders {
            out = out.replacingOccurrences(of: key, with: value)
        }
        return out
    }

    /// Stable seed input for the overview reading. Sorts symptom
    /// raws so order doesn't matter, then folds in the count of
    /// active and emerging – this way the seed shifts cleanly as
    /// the user's pattern set evolves cycle to cycle, but stays
    /// stable while the same set is in play.
    private static func seedKey(
        active: [DetectedPattern],
        emerging: [DetectedPattern]
    ) -> String {
        let activeKey = active.map(\.symptomTypeRaw).sorted().joined(separator: ",")
        let emergingKey = emerging.map(\.symptomTypeRaw).sorted().joined(separator: ",")
        return "a:[\(activeKey)]_e:[\(emergingKey)]"
    }

    // MARK: - Cluster detection

    private struct Cluster {
        let phase: CyclePhase
        let phaseName: String
        let patterns: [DetectedPattern]
        let cyclesRunning: Int
    }

    /// Finds the first phase that carries 2+ active patterns. The
    /// strongest narrative branch – phase clustering reads as the
    /// most useful shape ("your luteal patterns are clustering" vs
    /// "you have several patterns").
    private static func phaseCluster(_ active: [DetectedPattern]) -> Cluster? {
        let groups = Dictionary(grouping: active, by: \.phase)
        for (phase, patterns) in groups where patterns.count >= 2 {
            let cycles = patterns.map(\.totalCycles).min() ?? 0
            return Cluster(
                phase: phase,
                phaseName: phaseDisplayName(phase),
                patterns: patterns,
                cyclesRunning: cycles
            )
        }
        return nil
    }

    private static func phaseDisplayName(_ phase: CyclePhase) -> String {
        switch phase {
        case .menstrual:  return "menstrual"
        case .follicular: return "follicular"
        case .ovulatory:  return "ovulatory"
        case .luteal:     return "luteal"
        case .late:       return "late luteal"
        }
    }

    /// Convert a raw symptom type like "breast_tenderness" into a
    /// human-readable form. The display layer owns the canonical
    /// mapping via `SymptomType.displayName`; this is the floor
    /// used by the engine when only the raw is available.
    private static func formatSymptomRaw(_ raw: String) -> String {
        raw.replacingOccurrences(of: "_", with: " ")
    }

    /// Oxford-comma list. "A and B" / "A, B, and C" / "A, B, C, and D".
    private static func listPhrase(_ items: [String]) -> String {
        guard let first = items.first else { return "" }
        let rest = Array(items.dropFirst())
        switch rest.count {
        case 0:
            return first
        case 1:
            return "\(first) and \(rest[0])"
        default:
            let head = rest.dropLast().joined(separator: ", ")
            return "\(first), \(head), and \(rest.last!)"
        }
    }
}
