// Packages/Features/Home/Glow/PhotoCaptureRepresentables.swift
//
// AVFoundation-backed inline camera for the challenge proof step. Replaces
// the previous UIImagePickerController-based camera + PHPickerViewController
// gallery flows; the journey now captures photos inline (no modals).

import AVFoundation
import SwiftUI
import UIKit

// MARK: - Camera Session (model)

/// Owns the AVCaptureSession and exposes a photo-capture API. Must be
/// started with `start()` when the view appears and `stop()` when it
/// disappears to release the hardware. The controller is MainActor-bound
/// so published state stays on the UI actor; the session itself is
/// driven off a private serial queue.
@MainActor
final class CameraCaptureController: NSObject, ObservableObject {
    enum Availability: Equatable, Sendable {
        case unknown
        case authorized
        case denied
        case unavailable // simulator / no hardware
    }

    @Published var availability: Availability = .unknown
    @Published var isSessionRunning: Bool = false
    @Published var capturedImageData: Data?

    nonisolated(unsafe) let session = AVCaptureSession()
    nonisolated(unsafe) private let output = AVCapturePhotoOutput()
    nonisolated(unsafe) private let sessionQueue = DispatchQueue(label: "app.cycle.ios.camera-session")
    nonisolated(unsafe) private var hasConfigured = false

    override init() {
        super.init()
    }

    // MARK: - Permission + Configuration

    func requestPermissionAndConfigure() {
        #if targetEnvironment(simulator)
        availability = .unavailable
        return
        #else
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            availability = .authorized
            configureAndStartIfNeeded()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    guard let self else { return }
                    self.availability = granted ? .authorized : .denied
                    if granted { self.configureAndStartIfNeeded() }
                }
            }
        case .denied, .restricted:
            availability = .denied
        @unknown default:
            availability = .denied
        }
        #endif
    }

    nonisolated private func configureAndStartIfNeeded() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.hasConfigured {
                self.configureSessionOnQueue()
                self.hasConfigured = true
            }
            if !self.session.isRunning {
                self.session.startRunning()
            }
            let running = self.session.isRunning
            Task { @MainActor in self.isSessionRunning = running }
        }
    }

    nonisolated private func configureSessionOnQueue() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        // Back camera input
        if
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        {
            session.addInput(input)
        }

        // Photo output
        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        session.commitConfiguration()
    }

    // MARK: - Start / Stop

    func start() {
        #if targetEnvironment(simulator)
        return
        #else
        guard availability == .authorized else { return }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.session.isRunning {
                self.session.startRunning()
                let running = self.session.isRunning
                Task { @MainActor in self.isSessionRunning = running }
            }
        }
        #endif
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
                Task { @MainActor in self.isSessionRunning = false }
            }
        }
    }

    // MARK: - Capture

    func capturePhoto() {
        #if targetEnvironment(simulator)
        return
        #else
        guard availability == .authorized, session.isRunning else { return }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            // Prefer JPEG output so downstream re-encoding is a no-op
            // and the base64 payload sent to the validate endpoint stays
            // small and format-predictable (HEIC can bloat and has caused
            // JSON decode failures server-side on slower networks).
            let settings: AVCapturePhotoSettings
            if self.output.availablePhotoCodecTypes.contains(.jpeg) {
                settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            } else {
                settings = AVCapturePhotoSettings()
            }
            if self.output.supportedFlashModes.contains(.auto) {
                settings.flashMode = .auto
            }
            self.output.capturePhoto(with: settings, delegate: self)
        }
        #endif
    }

    func clearCapture() {
        capturedImageData = nil
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraCaptureController: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil, let data = photo.fileDataRepresentation() else { return }
        Task { @MainActor in
            self.capturedImageData = data
        }
    }
}

// MARK: - SwiftUI Preview View

/// Lightweight SwiftUI wrapper around an AVCaptureVideoPreviewLayer. The
/// layer uses aspect-fill so the live preview completely covers the
/// rounded stage we clip it to.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewContainer {
        let view = PreviewContainer()
        view.backgroundColor = .black
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewContainer, context: Context) {
        if uiView.videoPreviewLayer.session !== session {
            uiView.videoPreviewLayer.session = session
        }
    }

    final class PreviewContainer: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            // Safe force-cast: `layerClass` is overridden above.
            // swiftlint:disable:next force_cast
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}

// MARK: - Photo Processor

enum PhotoProcessor {
    /// Max dimension for the uploaded JPEG. 896px + 0.6 quality produces
    /// ~120–220 KB binary / ~160–300 KB base64, well under the backend's
    /// 2 MB body limit and cheap enough that the validate POST doesn't
    /// thrash memory on older devices.
    static let uploadMaxDimension: CGFloat = 896
    static let uploadQuality: CGFloat = 0.6

    static func process(_ imageData: Data) -> (fullSize: Data, thumbnail: Data)? {
        guard let image = UIImage(data: imageData) else { return nil }

        let fullSize = resized(image, maxDimension: uploadMaxDimension)
        guard let fullData = fullSize.jpegData(compressionQuality: uploadQuality) else { return nil }

        let thumb = resized(image, maxDimension: 200)
        guard let thumbData = thumb.jpegData(compressionQuality: 0.6) else { return nil }

        return (fullData, thumbData)
    }

    private static func resized(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return image }
        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
