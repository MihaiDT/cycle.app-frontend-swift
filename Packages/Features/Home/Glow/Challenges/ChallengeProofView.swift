// Packages/Features/Home/Glow/ChallengeProofView.swift
//
// Inline camera + paparazzi-style photo reveal. Replaces the previous
// picker-based flow (UIImagePickerController / PHPickerViewController):
// the camera preview is now rendered directly inside the journey step
// and a captured photo animates in with a random tilt ("photo dropped
// on the table"). Respects reduceMotion and DesignSystem tokens.

import AVFoundation
import ComposableArchitecture
import SwiftUI
import UIKit

struct ChallengeProofView: View {
    let store: StoreOf<ChallengeJourneyFeature>

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var camera = CameraCaptureController()

    @State private var capturedTilt: Double = 0
    @State private var hasRevealedPhoto: Bool = false
    @State private var shutterPressed: Bool = false

    // Visual tuning knobs surfaced here so PM can tweak later.
    private let tiltRange: ClosedRange<Double> = -10...10
    private let photoCornerRadius: CGFloat = 8
    private let polaroidBorder: CGFloat = 12
    private let revealScaleFrom: CGFloat = 0.6
    private let revealOffsetFrom: CGFloat = 80

    var body: some View {
        VStack(spacing: 16) {
            validationPromptPill

            if let data = store.capturedFullSize, let uiImage = UIImage(data: data) {
                paparazziPhoto(uiImage)
                    .frame(maxWidth: .infinity)
            } else {
                cameraStage
            }

            Spacer(minLength: 0)

            bottomCluster
        }
        .onAppear {
            // Only request permission if we don't already have a photo —
            // returning from retake handles its own `start()` call.
            if store.capturedFullSize == nil {
                camera.requestPermissionAndConfigure()
            }
        }
        .onDisappear {
            camera.stop()
        }
        .onChange(of: camera.capturedImageData) { _, data in
            guard let data else { return }
            // Reducer owns thumbnail generation (PhotoProcessor.process)
            // via the existing `.photoCaptured(Data)` action — we only
            // deliver the raw bytes and let the feature reshape them.
            store.send(.photoCaptured(data))
            capturedTilt = reduceMotion ? 0 : Double.random(in: tiltRange)
            if reduceMotion {
                hasRevealedPhoto = true
            } else {
                withAnimation(.appReveal) {
                    hasRevealedPhoto = true
                }
            }
            camera.stop()
            camera.clearCapture()
        }
    }

    // MARK: - Validation Prompt Pill

    private var validationPromptPill: some View {
        Text(store.challenge.validationPrompt)
            .font(.custom("Raleway-SemiBold", size: 12, relativeTo: .footnote))
            .foregroundStyle(DesignColors.textPrincipal)
            .multilineTextAlignment(.center)
            .padding(.horizontal, AppLayout.screenHorizontal)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(DesignColors.cardWarm)
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(DesignColors.divider, lineWidth: 1)
                    )
            )
            .frame(maxWidth: .infinity)
            .accessibilityHint("Validation prompt for this challenge")
    }

    // MARK: - Camera Stage

    @ViewBuilder
    private var cameraStage: some View {
        switch camera.availability {
        case .unknown, .authorized:
            cameraPreviewStage
        case .denied:
            permissionDeniedCard
        case .unavailable:
            simulatorPlaceholder
        }
    }

    private var cameraPreviewStage: some View {
        ZStack {
            if camera.availability == .authorized {
                CameraPreviewView(session: camera.session)
                    .transition(.opacity)
                    .accessibilityLabel("Live camera preview")
            } else {
                // Pre-authorization shim: matches the final rounded stage
                // so the layout doesn't jump when the session starts.
                Rectangle()
                    .fill(DesignColors.cardWarm)
                    .overlay(
                        Text("Preparing camera…")
                            .font(.custom("Raleway-Medium", size: 13, relativeTo: .footnote))
                            .foregroundStyle(DesignColors.textPlaceholder)
                    )
            }
        }
        .aspectRatio(3.0 / 4.0, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(DesignColors.divider, lineWidth: 1)
        )
        .shadow(color: DesignColors.text.opacity(0.10), radius: 12, x: 0, y: 4)
    }

    private var simulatorPlaceholder: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(DesignColors.cardWarm)
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay(
                VStack(spacing: 10) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 32, weight: .regular))
                        .foregroundStyle(DesignColors.textPlaceholder)
                    Text("Camera unavailable in simulator")
                        .font(.custom("Raleway-SemiBold", size: 13, relativeTo: .footnote))
                        .foregroundStyle(DesignColors.textPrincipal)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(DesignColors.divider, lineWidth: 1)
            )
            .accessibilityLabel("Camera unavailable in simulator")
    }

    private var permissionDeniedCard: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(DesignColors.cardWarm)
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay(
                VStack(spacing: 14) {
                    Image(systemName: "camera.slash.fill")
                        .font(.system(size: 32, weight: .regular))
                        .foregroundStyle(DesignColors.textPlaceholder)
                    Text("Camera access is off")
                        .font(.custom("Raleway-Bold", size: 15, relativeTo: .body))
                        .foregroundStyle(DesignColors.text)
                    Text("Open Settings to enable the camera for this challenge.")
                        .font(.custom("Raleway-Medium", size: 12, relativeTo: .footnote))
                        .foregroundStyle(DesignColors.textPrincipal)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Button(action: openSettings) {
                        Text("Open Settings")
                            .font(.custom("Raleway-SemiBold", size: 13, relativeTo: .footnote))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(DesignColors.accentWarm)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens the Settings app")
                }
                .padding(.horizontal, 20)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(DesignColors.divider, lineWidth: 1)
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Camera access is off. Open Settings to enable.")
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Paparazzi Photo Reveal

    @ViewBuilder
    private func paparazziPhoto(_ image: UIImage) -> some View {
        ZStack {
            // Subtle "back of the stack" ghost — only when motion is allowed.
            if !reduceMotion {
                polaroid(image)
                    .opacity(0.22)
                    .blur(radius: 4)
                    .rotationEffect(.degrees(capturedTilt + (capturedTilt >= 0 ? -6 : 6)))
                    .offset(y: 8)
                    .accessibilityHidden(true)
            }

            polaroid(image)
                .rotationEffect(.degrees(reduceMotion ? 0 : capturedTilt))
                .scaleEffect(hasRevealedPhoto ? 1.0 : revealScaleFrom)
                .opacity(hasRevealedPhoto ? 1.0 : 0.0)
                .offset(y: hasRevealedPhoto ? 0 : revealOffsetFrom)
                .accessibilityLabel("Your challenge photo")
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private func polaroid(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .clipped()
            .padding(.horizontal, polaroidBorder)
            .padding(.top, polaroidBorder)
            .padding(.bottom, polaroidBorder * 3) // classic polaroid weighted base
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: photoCornerRadius, style: .continuous))
            .shadow(color: DesignColors.text.opacity(0.18), radius: 24, x: 0, y: 12)
            .shadow(color: DesignColors.text.opacity(0.10), radius: 4, x: 0, y: 1)
    }

    // MARK: - Bottom Cluster

    @ViewBuilder
    private var bottomCluster: some View {
        if store.capturedFullSize != nil {
            postCaptureControls
        } else {
            shutterButton
        }
    }

    private var shutterButton: some View {
        Button {
            guard camera.availability == .authorized else { return }
            if !reduceMotion {
                withAnimation(.appBalanced) { shutterPressed = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    withAnimation(.appBalanced) { shutterPressed = false }
                }
            }
            camera.capturePhoto()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 72, height: 72)
                    .shadow(color: DesignColors.text.opacity(0.18), radius: 10, x: 0, y: 4)
                Circle()
                    .strokeBorder(DesignColors.text.opacity(0.1), lineWidth: 2)
                    .frame(width: 64, height: 64)
            }
            .scaleEffect(shutterPressed ? 0.92 : 1.0)
            .frame(minWidth: 72, minHeight: 72)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(camera.availability != .authorized)
        .opacity(camera.availability == .authorized ? 1.0 : 0.45)
        .accessibilityLabel("Capture photo")
        .accessibilityHint("Takes a photo of your challenge result")
    }

    private var postCaptureControls: some View {
        VStack(spacing: 10) {
            Button { store.send(.submitPhotoTapped) } label: {
                Text("Submit")
                    .font(.custom("Raleway-Bold", size: 17, relativeTo: .body))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(DesignColors.accentWarm)
                    )
                    .shadow(color: DesignColors.text.opacity(0.22), radius: 10, x: 0, y: 4)
                    .shadow(color: DesignColors.text.opacity(0.10), radius: 3, x: 0, y: 1)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Sends the photo for review")

            Button {
                // Reset reveal + tilt so the next capture animates fresh,
                // then resume the preview session.
                hasRevealedPhoto = false
                capturedTilt = 0
                store.send(.retakeTapped)
                camera.requestPermissionAndConfigure()
                camera.start()
            } label: {
                Text("Retake")
                    .font(.custom("Raleway-SemiBold", size: 14, relativeTo: .body))
                    .foregroundStyle(DesignColors.textPlaceholder)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Retake photo")
            .accessibilityHint("Discards this photo and reopens the camera")
        }
    }
}
