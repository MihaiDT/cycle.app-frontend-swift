import SwiftUI

// MARK: - NyraOrb › Animation Lifecycle
//
// Breath / blink / gaze / glance / drift / blob-morph animation
// loops. Lifted out of NyraOrb.swift so the main file can focus on
// layout + composition. Methods stay `func` (default internal)
// within the extension; the @State they mutate was upgraded from
// private to internal in the primary struct declaration.

extension NyraOrb {
    /// Kick off every ambient loop — called on appear and when the
    /// scene returns to active from background.
    func startAllLoops() {
        startBreath()
        startBlink()
        startGaze()
        startEyesGlance()
        startDrift()
        startBlobMorph()
    }

    /// Siri-style blob morph — two interpolating phases running at
    /// different speeds so the silhouette wobbles asymmetrically and
    /// never repeats exactly. Driven by SwiftUI animations so it's
    /// smooth on the render thread without per-frame ticks.
    func startBlobMorph() {
        guard !reduceMotion else {
            blobPhase = 0
            blobPhase2 = 0
            return
        }
        blobPhase = 0
        blobPhase2 = 0
        withAnimation(.easeInOut(duration: 4.8 / speed).repeatForever(autoreverses: true)) {
            blobPhase = 1
        }
        withAnimation(.easeInOut(duration: 7.2 / speed).repeatForever(autoreverses: true)) {
            blobPhase2 = 1
        }
    }

    /// Cancel every active task/animation so Nyra stops consuming CPU
    /// when her view leaves the screen or the app backgrounds.
    func stopAllLoops() {
        blinkTask?.cancel(); blinkTask = nil
        gazeTask?.cancel(); gazeTask = nil
        glanceTask?.cancel(); glanceTask = nil
        blink = false
        gaze = .zero
        eyesOpen = false
    }

    // MARK: - Breath cycle

    func startBreath() {
        guard !reduceMotion else {
            breathScale = 1.0
            return
        }
        // Siri-style breath — more pronounced amplitude so the sphere
        // feels actively alive. No face means pulse carries the
        // personality, so we lean into it.
        let (duration, amplitude): (Double, CGFloat) = {
            switch mood {
            case .idle:         return (3.6 / speed, 0.035)
            case .listening:    return (2.2 / speed, 0.045)
            case .speaking:     return (2.8 / speed, 0.040)
            case .thinking:     return (2.4 / speed, 0.035)
            case .comforting:   return (3.4 / speed, 0.050)
            case .celebrating:  return (1.4 / speed, 0.075)
            }
        }()
        breathScale = 1.0
        withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
            breathScale = 1.0 + amplitude
        }
    }

    func startBlink() {
        guard !reduceMotion else { return }
        blinkTask?.cancel()
        blinkTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64((2.6 / speed + Double.random(in: 0...0.9)) * 1_000_000_000))
                blink = true
                try? await Task.sleep(nanoseconds: 130_000_000)
                blink = false
            }
        }
    }

    func startGaze() {
        guard !reduceMotion else { return }
        gazeTask?.cancel()
        gazeTask = Task { @MainActor in
            while !Task.isCancelled {
                let angle = Double.random(in: 0...(2 * .pi))
                let radius = Double.random(in: 0.8...2.2)
                let offset = CGSize(
                    width: cos(angle) * radius,
                    height: sin(angle) * radius * 0.5
                )
                withAnimation(.easeOut(duration: 0.45)) {
                    gaze = offset
                }
                try? await Task.sleep(nanoseconds: UInt64((2.4 / speed) * 1_000_000_000))
            }
        }
    }

    /// Speaking mood keeps the pill eyes open by default — Nyra is
    /// addressing the user, so she's engaged and attentive. Every so
    /// often she "blinks" (the pills squish shut for ~110ms). Other
    /// moods keep the resting arc expression and never auto-open.
    func startEyesGlance() {
        guard !reduceMotion, mood == .speaking else {
            eyesOpen = false
            return
        }
        glanceTask?.cancel()
        // Open pills immediately on appear — default resting state for
        // the speaking mood. Small delay so the sphere settles first.
        glanceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(Double.random(in: 0.4...0.9) * 1_000_000_000))
            withAnimation(.spring(response: 0.48, dampingFraction: 0.72)) {
                eyesOpen = true
            }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(Double.random(in: 3.5...6.5) * 1_000_000_000))
                blink = true
                try? await Task.sleep(nanoseconds: 110_000_000)
                blink = false
            }
        }
    }

    /// Floaty idle drift — two-axis SwiftUI animation with slightly
    /// different durations so the motion never repeats exactly. Runs
    /// entirely via the animation system, no per-frame ticks.
    func startDrift() {
        guard !reduceMotion else {
            driftPhaseX = 0
            driftPhaseY = 0
            return
        }
        driftPhaseX = -1
        driftPhaseY = -1
        withAnimation(.easeInOut(duration: 3.8 / speed).repeatForever(autoreverses: true)) {
            driftPhaseX = 1
        }
        withAnimation(.easeInOut(duration: 5.4 / speed).repeatForever(autoreverses: true)) {
            driftPhaseY = 1
        }
    }

    // MARK: - Per-frame derived values

    func idleDrift(t: TimeInterval) -> CGSize {
        guard !reduceMotion else { return .zero }
        return CGSize(
            width: sin(t * 0.7) * 3,
            height: cos(t * 0.5) * 4 + sin(t * 1.3) * 1.5
        )
    }

    func speakingPulse(t: TimeInterval) -> Double {
        1 + (sin(t * 9) * 0.025 + sin(t * 3.2) * 0.015)
    }
}
