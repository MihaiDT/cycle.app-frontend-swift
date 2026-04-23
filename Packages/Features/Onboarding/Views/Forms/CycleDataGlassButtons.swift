import SwiftUI

// MARK: - Glass Duration Button

private struct GlassDurationButton: View {
    let label: String
    let value: String
    let unit: String
    let accentColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(label)
                    .font(.raleway("Medium", size: 13, relativeTo: .caption))
                    .foregroundColor(DesignColors.text.opacity(0.6))

                HStack(spacing: 4) {
                    Text(value)
                        .font(.raleway("Bold", size: 24, relativeTo: .title2))
                        .foregroundColor(accentColor)

                    Text(unit)
                        .font(.raleway("Regular", size: 14, relativeTo: .body))
                        .foregroundColor(DesignColors.text.opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.5),
                                        Color.white.opacity(0.1),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Glass Selection Button

private struct GlassSelectionButton: View {
    let label: String
    let value: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.raleway("Medium", size: 13, relativeTo: .caption))
                        .foregroundColor(DesignColors.text.opacity(0.6))

                    Text(value)
                        .font(.raleway("SemiBold", size: 16, relativeTo: .body))
                        .foregroundColor(DesignColors.text)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignColors.text.opacity(0.4))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 24)
            .frame(height: 64)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.5),
                                        Color.white.opacity(0.1),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow Intensity Selector

struct FlowIntensitySelector: View {
    @Binding var intensity: Int

    private var intensityLabel: String {
        switch intensity {
        case 1: return "Very Light"
        case 2: return "Light"
        case 3: return "Moderate"
        case 4: return "Heavy"
        case 5: return "Very Heavy"
        default: return "Moderate"
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Flow intensity")
                        .font(.raleway("Medium", size: 13, relativeTo: .caption))
                        .foregroundColor(DesignColors.text.opacity(0.6))

                    Text(intensityLabel)
                        .font(.raleway("SemiBold", size: 16, relativeTo: .body))
                        .foregroundColor(DesignColors.text)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Flow intensity: \(intensityLabel)")

                Spacer()
            }

            // Intensity dots
            HStack(spacing: 12) {
                ForEach(1...5, id: \.self) { level in
                    Button(action: {
                        withAnimation(.appBalanced) {
                            intensity = level
                        }
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    }) {
                        Circle()
                            .fill(level <= intensity ? DesignColors.accent : DesignColors.text.opacity(0.15))
                            .frame(width: 20 + CGFloat(level) * 6, height: 20 + CGFloat(level) * 6)
                            .overlay {
                                if level == intensity {
                                    Circle()
                                        .strokeBorder(Color.white.opacity(0.6), lineWidth: 2)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Flow level \(level) of 5")
                    .accessibilityAddTraits(level == intensity ? [.isSelected, .isButton] : [.isButton])
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background {
            RoundedRectangle(cornerRadius: 24)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.5),
                                    Color.white.opacity(0.1),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
                .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
        }
    }
}

// MARK: - Glass Symptoms Button

private struct GlassSymptomsButton: View {
    let selectedSymptoms: Set<SymptomType>
    let action: () -> Void

    private var symptomNames: String {
        let sorted = selectedSymptoms.sorted { $0.displayName < $1.displayName }
        return sorted.map { $0.displayName }.joined(separator: ", ")
    }

    var body: some View {
        Button(action: action) {
            HStack {
                if selectedSymptoms.isEmpty {
                    Text("Add typical symptoms")
                        .font(.raleway("Medium", size: 15, relativeTo: .body))
                        .foregroundColor(DesignColors.text.opacity(0.6))
                } else {
                    Text(symptomNames)
                        .font(.raleway("Medium", size: 15, relativeTo: .body))
                        .foregroundColor(DesignColors.text)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignColors.text.opacity(0.4))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 24)
            .frame(height: 57)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.5),
                                        Color.white.opacity(0.1),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Glass Contraception Button

private struct GlassContraceptionButton: View {
    let usesContraception: Bool
    let contraceptionType: ContraceptionType?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                if usesContraception, let type = contraceptionType {
                    Text(type.displayName)
                        .font(.raleway("SemiBold", size: 15, relativeTo: .body))
                        .foregroundColor(DesignColors.text)
                } else if usesContraception {
                    Text("Using contraception")
                        .font(.raleway("Medium", size: 15, relativeTo: .body))
                        .foregroundColor(DesignColors.text.opacity(0.8))
                } else {
                    Text("Not using contraception")
                        .font(.raleway("Medium", size: 15, relativeTo: .body))
                        .foregroundColor(DesignColors.text.opacity(0.6))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(DesignColors.text.opacity(0.4))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 24)
            .frame(height: 57)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.5),
                                        Color.white.opacity(0.1),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(
                at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y),
                proposal: .unspecified
            )
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing

                self.size.width = max(self.size.width, x - spacing)
            }

            self.size.height = y + rowHeight
        }
    }
}

