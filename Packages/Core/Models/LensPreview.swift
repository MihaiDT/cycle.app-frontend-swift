import Foundation
import SwiftUI

// MARK: - Lens Preview
//
// A teaser for a deeper reflection experience that lives in the Lens
// surface. Home's "Your day" section stacks these vertically; tapping one
// opens Lens to the corresponding session. The model is transport-agnostic
// — today a mock client produces it, tomorrow a backend generates it —
// so no view code needs to change when the real pipeline lands.

public struct LensPreview: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let title: String
    public let teaser: String
    public let durationMinutes: Int
    public let tone: Tone
    public let phase: CyclePhase
    public let cycleDay: Int

    public init(
        id: UUID = UUID(),
        title: String,
        teaser: String,
        durationMinutes: Int,
        tone: Tone,
        phase: CyclePhase,
        cycleDay: Int
    ) {
        self.id = id
        self.title = title
        self.teaser = teaser
        self.durationMinutes = durationMinutes
        self.tone = tone
        self.phase = phase
        self.cycleDay = cycleDay
    }
}

// MARK: - Tone

/// Visual tone applied to a Lens preview card. Drives the gradient wash
/// behind the content, so the card feels emotionally matched to its
/// theme without the user having to read the copy. Colours stay in the
/// app's warm palette — nothing cold or clinical.
public enum Tone: String, Equatable, Sendable, Codable {
    case tender      // soft rose — low-energy, comforting
    case curious     // warm amber — inquisitive, open
    case grounding   // sage — steadying, earthy
    case reflective  // dusk lavender — quiet introspection

    /// Two-stop gradient used as the card's background wash.
    public var gradient: [Color] {
        switch self {
        case .tender:
            return [Color(hex: 0xFCE9E6), Color(hex: 0xF6D6D0)]
        case .curious:
            return [Color(hex: 0xFBEBD2), Color(hex: 0xF5D9B6)]
        case .grounding:
            return [Color(hex: 0xE7EDDA), Color(hex: 0xD2DEBF)]
        case .reflective:
            return [Color(hex: 0xE7E2EE), Color(hex: 0xD4CCE0)]
        }
    }

    /// Accent color for the tone — used by the bottom CTA + small meta.
    public var accent: Color {
        switch self {
        case .tender:     return Color(hex: 0x8C3E36)
        case .curious:    return Color(hex: 0x8A5A1E)
        case .grounding:  return Color(hex: 0x4F5F3A)
        case .reflective: return Color(hex: 0x54487A)
        }
    }
}
