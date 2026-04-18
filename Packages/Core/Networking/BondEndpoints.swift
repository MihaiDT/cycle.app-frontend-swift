import Foundation

// MARK: - Bond Request/Response Models

public struct UploadPublicKeyRequest: Encodable, Sendable {
    public let publicKey: String

    public init(publicKey: String) {
        self.publicKey = publicKey
    }
}

public struct PublicKeyResponse: Decodable, Sendable {
    public let publicKey: String
}

public struct CreateBondRequest: Encodable, Sendable {
    public let recipientAnonymousId: String

    public init(recipientAnonymousId: String) {
        self.recipientAnonymousId = recipientAnonymousId
    }
}

public struct BondResponse: Decodable, Sendable {
    public let bondId: String
    public let status: String
    public let initiatorAnonymousId: String
    public let recipientAnonymousId: String
}

public struct UploadBlobRequest: Encodable, Sendable {
    public let blobType: String
    public let encryptedData: String

    public init(blobType: String, encryptedData: String) {
        self.blobType = blobType
        self.encryptedData = encryptedData
    }
}

public struct BlobResponse: Decodable, Sendable {
    public let blobId: String
    public let blobType: String
    public let encryptedData: String
}

public struct UploadKeyRecoveryRequest: Encodable, Sendable {
    public let encryptedRecoveryKey: String

    public init(encryptedRecoveryKey: String) {
        self.encryptedRecoveryKey = encryptedRecoveryKey
    }
}

public struct KeyRecoveryResponse: Decodable, Sendable {
    public let encryptedRecoveryKey: String
}

// MARK: - Bond Endpoints

extension Endpoint {

    // PUT /api/{anonymousID}/keys
    public static func uploadPublicKey(anonymousID: String, body: UploadPublicKeyRequest) -> Endpoint {
        .put("/api/\(anonymousID)/keys", body: body)
    }

    // GET /api/{anonymousID}/keys
    public static func getPublicKey(anonymousID: String) -> Endpoint {
        .get("/api/\(anonymousID)/keys")
    }

    // POST /api/{anonymousID}/bonds
    public static func createBond(anonymousID: String, body: CreateBondRequest) -> Endpoint {
        .post("/api/\(anonymousID)/bonds", body: body)
    }

    // POST /api/{anonymousID}/bonds/{bondID}/accept
    public static func acceptBond(anonymousID: String, bondID: String) -> Endpoint {
        .post("/api/\(anonymousID)/bonds/\(bondID)/accept", body: EmptyBody())
    }

    // GET /api/{anonymousID}/bonds
    public static func getMyBonds(anonymousID: String) -> Endpoint {
        .get("/api/\(anonymousID)/bonds")
    }

    // DELETE /api/{anonymousID}/bonds/{bondID}/revoke
    public static func revokeBond(anonymousID: String, bondID: String) -> Endpoint {
        .delete("/api/\(anonymousID)/bonds/\(bondID)/revoke")
    }

    // PUT /api/{anonymousID}/bonds/{bondID}/blobs
    public static func uploadBlob(anonymousID: String, bondID: String, body: UploadBlobRequest) -> Endpoint {
        .put("/api/\(anonymousID)/bonds/\(bondID)/blobs", body: body)
    }

    // GET /api/{anonymousID}/bonds/{bondID}/blobs?type={blobType}
    public static func getBlobs(anonymousID: String, bondID: String, blobType: String) -> Endpoint {
        .get(
            "/api/\(anonymousID)/bonds/\(bondID)/blobs",
            queryItems: [URLQueryItem(name: "type", value: blobType)]
        )
    }

    // PUT /api/{anonymousID}/key-recovery
    public static func uploadKeyRecovery(anonymousID: String, body: UploadKeyRecoveryRequest) -> Endpoint {
        .put("/api/\(anonymousID)/key-recovery", body: body)
    }

    // GET /api/{anonymousID}/key-recovery
    public static func getKeyRecovery(anonymousID: String) -> Endpoint {
        .get("/api/\(anonymousID)/key-recovery")
    }
}
