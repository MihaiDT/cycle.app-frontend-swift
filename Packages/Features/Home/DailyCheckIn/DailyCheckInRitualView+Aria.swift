import SwiftUI

// MARK: - DailyCheckInRitualView › Aria Page + Reactive Background

extension DailyCheckInRitualView {
    var ariaPage: some View {
        let tokens = ariaTokens()
        return VStack(spacing: 0) {
            Spacer()

            NyraOrb(size: 138, mood: .comforting)
                .padding(.bottom, 28)

            // Summary of selections — the four words the user picked
            summaryRow
                .padding(.bottom, 28)

            // Word-by-word reveal
            RitualFlowLayout(spacing: 6, lineSpacing: 6) {
                ForEach(Array(tokens.enumerated()), id: \.offset) { index, token in
                    Group {
                        if token.emphasized {
                            Text(token.word).italic()
                                .font(.raleway("SemiBold", size: 28, relativeTo: .title2))
                                .foregroundStyle(DesignColors.accentWarmText)
                        } else {
                            Text(token.word)
                                .font(.raleway("Regular", size: 28, relativeTo: .title2))
                                .foregroundStyle(DesignColors.text)
                        }
                    }
                    .opacity(index < ariaVisibleCount ? 1 : 0)
                    .offset(y: index < ariaVisibleCount ? 0 : 10)
                    .animation(.easeOut(duration: 0.7), value: ariaVisibleCount)
                }
            }
            .padding(.horizontal, 38)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)

            Spacer()

            if let errorMessage = store.error {
                Text(errorMessage)
                    .font(.raleway("Medium", size: 12, relativeTo: .caption))
                    .foregroundStyle(Color.red.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
                    .padding(.bottom, 12)
                    .transition(.opacity)
            }

            HStack {
                Spacer()
                Button(action: closeRitual) {
                    HStack(spacing: 8) {
                        if store.isSubmitting {
                            ProgressView()
                                .tint(DesignColors.text)
                        }
                        Text(store.isSubmitting ? "Saving…" : "All done")
                            .font(.raleway("SemiBold", size: 15, relativeTo: .headline))
                            .foregroundStyle(DesignColors.text)
                    }
                    .padding(.horizontal, 32)
                    .frame(height: 52)
                    .glassEffectCapsule()
                    .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(.plain)
                .disabled(store.isSubmitting)
                .fixedSize()
                Spacer()
            }
            .opacity(ariaCloseVisible ? 1 : 0)
            .offset(y: ariaCloseVisible ? 0 : 8)
            .animation(.easeOut(duration: 0.6), value: ariaCloseVisible)
            .padding(.bottom, 56)
        }
    }

    var line: some View {
        Rectangle()
            .fill(DesignColors.accentWarm.opacity(0.35))
            .frame(width: 22, height: 1)
    }


    // MARK: - Reactive background

    var reactiveBackground: some View {
        LinearGradient(
            stops: backgroundStops,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    var backgroundStops: [Gradient.Stop] {
        guard currentPage < 4 else {
            return [
                .init(color: Color(hex: 0xFDF2E4), location: 0.0),
                .init(color: Color(hex: 0xF2E4D3), location: 1.0)
            ]
        }
        let idx = answers[currentPage]
        let palette = Self.backgroundPalettes[currentPage]
        let pair = palette[idx]
        return [
            .init(color: pair.0, location: 0.0),
            .init(color: pair.1, location: 1.0)
        ]
    }

    // Four distinct palettes, all in the cycle.app warm brand family.
    // Each question has its own character (blush / coral / bloom / earth)
    // but stays within peach, rose, rust, and brown tones.
    static let backgroundPalettes: [[(Color, Color)]] = [
        // ── Heart — warm blush / rose ────────────────────────────
        [
            (Color(hex: 0xD9BBB7), Color(hex: 0xA67570)),
            (Color(hex: 0xE8CAC2), Color(hex: 0xC29F98)),
            (Color(hex: 0xFDE8E0), Color(hex: 0xF3C9C2)),
            (Color(hex: 0xFEE5DC), Color(hex: 0xF5B3A6)),
            (Color(hex: 0xFEF0E8), Color(hex: 0xFBCEBA))
        ],
        // ── Energy — amber peach / coral ─────────────────────────
        [
            (Color(hex: 0xD6C4BA), Color(hex: 0xA98A7B)),
            (Color(hex: 0xE6CDBA), Color(hex: 0xC29A85)),
            (Color(hex: 0xFCEDDC), Color(hex: 0xF1CEAE)),
            (Color(hex: 0xFED9BC), Color(hex: 0xF5A378)),
            (Color(hex: 0xFEE2C2), Color(hex: 0xFA8E5E))
        ],
        // ── Rest — dusty bloom (muted peach + soft rose) ─────────
        [
            (Color(hex: 0xE4CFC5), Color(hex: 0xB89B92)),
            (Color(hex: 0xEFD8CC), Color(hex: 0xC7A89E)),
            (Color(hex: 0xFCE6D4), Color(hex: 0xF3C9C2)),
            (Color(hex: 0xFDEEDD), Color(hex: 0xF6D4C7)),
            (Color(hex: 0xFDF2E8), Color(hex: 0xF9E2D6))
        ],
        // ── Weather — earth brown → ivory peach ──────────────────
        [
            (Color(hex: 0xA68877), Color(hex: 0x5C3B30)),
            (Color(hex: 0xC5A799), Color(hex: 0x8A5A1E)),
            (Color(hex: 0xE8CCB8), Color(hex: 0xC99B95)),
            (Color(hex: 0xFBE6D1), Color(hex: 0xF3C9C2)),
            (Color(hex: 0xFDF2E3), Color(hex: 0xFCE6D4))
        ]
    ]


    // MARK: - Aria summary row

    /// The four words the user chose across the ritual, separated by
    /// centered dots. A gentle closure / validation of the session.
    var summaryRow: some View {
        let chosen: [String] = (0..<4).map { i in
            Self.questions[i].words[answers[i]]
        }
        return HStack(spacing: 10) {
            ForEach(Array(chosen.enumerated()), id: \.offset) { idx, word in
                if idx > 0 {
                    Circle()
                        .fill(DesignColors.accentWarmText.opacity(0.35))
                        .frame(width: 3, height: 3)
                }
                Text(word)
                    .font(.raleway("Medium", size: 12, relativeTo: .caption))
                    .italic()
                    .foregroundStyle(DesignColors.accentWarmText.opacity(0.72))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Continue label

    func continueLabel(for pageIdx: Int) -> some View {
        let keyword: String
        switch pageIdx {
        case 0: keyword = "energy"
        case 1: keyword = "rest"
        case 2: keyword = "weather"
        case 3: keyword = "reflection"
        default: keyword = ""
        }
        return Text(keyword)
            .font(.raleway("Bold", size: 15, relativeTo: .headline))
            .italic()
            .foregroundStyle(DesignColors.text)
    }

}
