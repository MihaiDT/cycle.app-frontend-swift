import SwiftUI
import UIKit

// MARK: - Share Sheet
//
// Thin UIViewControllerRepresentable wrapper around
// `UIActivityViewController`. SwiftUI's native `ShareLink` works
// for trivial cases, but we want explicit control over the
// activity items, completion callback, and dismissal — so we
// embed the UIKit controller directly.
//
// The wrapper is also tighter than `ShareLink` for files because
// it inherits the system's default activity item provider (which
// reads the URL's file extension to pick the right preview).

struct ExportShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var onComplete: ((Bool) -> Void)?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, completed, _, _ in
            onComplete?(completed)
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
