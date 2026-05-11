import SwiftUI

/// Reusable section block: caps eyebrow + optional headline +
/// paragraph. Used across How Patterns Work, When to See a
/// Doctor, and About so the typographic rhythm stays identical.
///
/// `paragraph` is named explicitly (rather than `body`) so the
/// stored property doesn't collide with `View.body`.
struct EducationalSection: View {
    let eyebrow: String
    let title: String?
    let paragraph: String

    init(eyebrow: String, title: String? = nil, paragraph: String) {
        self.eyebrow = eyebrow
        self.title = title
        self.paragraph = paragraph
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(eyebrow)
                .font(.raleway("SemiBold", size: 18, relativeTo: .title3))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            DesignColors.text,
                            DesignColors.textPrincipal,
                            DesignColors.text.opacity(0.85),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if let title {
                Text(title)
                    .font(.raleway("Bold", size: 20, relativeTo: .title3))
                    .foregroundStyle(DesignColors.text)
                    .padding(.bottom, 2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(paragraph)
                .font(.raleway("Regular", size: 15, relativeTo: .body))
                .foregroundStyle(DesignColors.text.opacity(0.85))
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        // `interactive: false` — purely editorial content, no
        // tap target. Default `true` would trigger the iOS 26
        // glass press shader on every touch with no action,
        // wasting GPU on shader churn (and contributing to the
        // `IOSurfaceClientSetSurfaceNotify` console noise).
        .widgetCardStyle(cornerRadius: 24, interactive: false)
    }
}
