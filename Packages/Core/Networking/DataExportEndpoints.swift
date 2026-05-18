import Foundation

// MARK: - Data Export Email
//
// POST /api/data-export/email — relays a one-shot transactional
// email carrying the export bundle as an attachment. The backend
// is a pure pass-through: no DB writes, no logs of the recipient
// address or payload contents, no in-memory cache beyond the
// lifetime of the request.

public struct DataExportEmailRequest: Encodable, Sendable {
    public let to: String
    public let referenceCode: String
    public let payloadB64: String
    public let filename: String

    public init(to: String, referenceCode: String, payloadB64: String, filename: String) {
        self.to = to
        self.referenceCode = referenceCode
        self.payloadB64 = payloadB64
        self.filename = filename
    }
}

public struct DataExportEmailResponse: Decodable, Sendable {
    public let status: String
    public let messageId: String?
}

extension Endpoint {
    public static func sendDataExportEmail(body: DataExportEmailRequest) throws -> Endpoint {
        try .post("/api/data-export/email", body: body)
    }
}
