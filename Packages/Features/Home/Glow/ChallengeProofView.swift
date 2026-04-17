// Packages/Features/Home/Glow/ChallengeProofView.swift

import ComposableArchitecture
import SwiftUI

struct ChallengeProofView: View {
    let store: StoreOf<ChallengeJourneyFeature>

    var body: some View {
        VStack(spacing: 0) {
            topBar

            if let photoData = store.capturedFullSize,
               let uiImage = UIImage(data: photoData) {
                photoPreview(uiImage)
            } else {
                waitingForPhoto
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button { store.send(.closeTapped) } label: {
                ZStack {
                    Circle()
                        .fill(DesignColors.cardWarm)
                        .overlay(Circle().strokeBorder(DesignColors.divider, lineWidth: 1))
                    Image(systemName: "chevron.left")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DesignColors.textSecondary)
                }
                .frame(width: 28, height: 28)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")
            .accessibilityHint("Returns to the previous step")

            Spacer()

            Text("Show Aria")
                .font(.custom("Raleway-Bold", size: 13, relativeTo: .caption))
                .foregroundStyle(DesignColors.textPrincipal)
                .accessibilityAddTraits(.isHeader)

            Spacer()

            Color.clear
                .frame(width: 28, height: 28)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityHidden(true)
        }
        .padding(.bottom, 12)
    }

    // MARK: - Waiting State

    private var waitingForPhoto: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("Take a photo to show Aria")
                .font(.custom("Raleway-Medium", size: 14, relativeTo: .body))
                .foregroundStyle(DesignColors.textPlaceholder)

            Text(store.challenge.validationPrompt)
                .font(.custom("Raleway-SemiBold", size: 13, relativeTo: .body))
                .foregroundStyle(DesignColors.textPrincipal)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(DesignColors.cardWarm)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(DesignColors.divider, lineWidth: 1)
                        )
                )

            Spacer()

            HStack(spacing: 20) {
                Button { store.send(.openCameraTapped) } label: {
                    Text("Camera")
                        .font(.custom("Raleway-SemiBold", size: 15, relativeTo: .body))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(DesignColors.accentWarm)
                        )
                        .shadow(color: DesignColors.text.opacity(0.22), radius: 10, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open camera")
                .accessibilityHint("Takes a photo of your challenge result")

                Button { store.send(.openGalleryTapped) } label: {
                    Text("Gallery")
                        .font(.custom("Raleway-SemiBold", size: 15, relativeTo: .body))
                        .foregroundStyle(DesignColors.textPrincipal)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(DesignColors.cardWarm)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(DesignColors.structure, lineWidth: 1.5)
                                )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open gallery")
                .accessibilityHint("Picks an existing photo of your challenge result")
            }
        }
    }

    // MARK: - Photo Preview

    private func photoPreview(_ image: UIImage) -> some View {
        VStack(spacing: 16) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: DesignColors.text.opacity(0.12), radius: 12, x: 0, y: 4)
                .accessibilityLabel("Your challenge photo")

            Text("Aria will check if it matches your challenge")
                .font(.custom("Raleway-Medium", size: 12, relativeTo: .caption))
                .foregroundStyle(DesignColors.textPlaceholder)

            Spacer(minLength: 0)

            Button { store.send(.submitPhotoTapped) } label: {
                Text("Submit")
                    .font(.custom("Raleway-Bold", size: 15, relativeTo: .body))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(DesignColors.accentWarm)
                    )
                    .shadow(color: DesignColors.text.opacity(0.22), radius: 10, x: 0, y: 4)
                    .shadow(color: DesignColors.text.opacity(0.10), radius: 3, x: 0, y: 1)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Sends the photo for review")

            Button { store.send(.retakeTapped) } label: {
                Text("Retake")
                    .font(.custom("Raleway-SemiBold", size: 14, relativeTo: .body))
                    .foregroundStyle(DesignColors.textPlaceholder)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Retake photo")
            .accessibilityHint("Reopens the camera to capture again")
        }
    }
}
