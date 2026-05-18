import MessageUI
import SwiftUI
import UIKit

// MARK: - Mail Compose View
//
// `UIViewControllerRepresentable` wrapper around
// `MFMailComposeViewController`. Mirrors `ShareSheet.swift` —
// system UI presented as a SwiftUI sheet, with a small
// coordinator threading the delegate callback back as a
// `MFMailComposeResult` closure.
//
// Use `MailDraft` to pre-fill subject / body / recipients +
// attach a single file (the JSON export bundle). The user
// retains full control: they see the message and attachment,
// can edit any field, can cancel. Email is delivered through
// the user's own configured account — Apple Mail / Exchange /
// IMAP — never via our backend.
//
// Always gate the presentation with
// `MFMailComposeViewController.canSendMail()`; if it returns
// false there's no iOS Mail account configured and presenting
// the controller results in a blank screen.

struct MailDraft: Identifiable {
    let id = UUID()
    var subject: String
    var body: String
    var toRecipients: [String]
    var attachmentData: Data
    var attachmentMime: String
    var attachmentFilename: String
}

struct MailComposeView: UIViewControllerRepresentable {
    let draft: MailDraft
    var onResult: ((MFMailComposeResult, Error?) -> Void)?

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setSubject(draft.subject)
        controller.setMessageBody(draft.body, isHTML: false)
        controller.setToRecipients(draft.toRecipients)
        controller.addAttachmentData(
            draft.attachmentData,
            mimeType: draft.attachmentMime,
            fileName: draft.attachmentFilename
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onResult: onResult)
    }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onResult: ((MFMailComposeResult, Error?) -> Void)?

        init(onResult: ((MFMailComposeResult, Error?) -> Void)?) {
            self.onResult = onResult
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            // The MFMailComposeViewControllerDelegate callback fires
            // on the main thread, so we can dismiss + report inline
            // instead of nesting the report inside dismiss's completion
            // — that nesting triggered Swift 6's non-Sendable closure
            // check because Error? isn't Sendable.
            controller.dismiss(animated: true)
            onResult?(result, error)
        }
    }
}
