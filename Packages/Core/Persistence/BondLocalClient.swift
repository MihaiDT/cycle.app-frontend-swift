import ComposableArchitecture
import Foundation

public struct BondLocalClient: Sendable {
    public var initializeKeys: @Sendable () async throws -> Void
    public var getPublicKey: @Sendable () throws -> Data
    public var createBond: @Sendable (_ partnerID: String) async throws -> BondInfo
    public var acceptBond: @Sendable (_ bondID: String) async throws -> BondInfo
    public var getMyBonds: @Sendable () async throws -> [BondInfo]
    public var revokeBond: @Sendable (_ bondID: String) async throws -> Void
    public var uploadSummary: @Sendable (_ bondID: String, _ summary: BondSummary) async throws -> Void
    public var downloadPartnerSummary: @Sendable (_ bondID: String) async throws -> BondSummary?
    public var backupKey: @Sendable (_ password: String) async throws -> Void
    public var restoreKey: @Sendable (_ password: String) async throws -> Void
}

// MARK: - Errors

public enum BondLocalError: Error, Sendable {
    case missingKeys
    case missingPublicKey
    case missingSecretKey
    case invalidBase64
    case invalidRecoveryData
}

// MARK: - Live Implementation

extension BondLocalClient {
    public static func live() -> BondLocalClient {
        @Dependency(\.bondCrypto) var bondCrypto
        @Dependency(\.keychainClient) var keychain
        @Dependency(\.apiClient) var api
        @Dependency(\.anonymousID) var anonymousID

        return BondLocalClient(
            initializeKeys: {
                // Check if keys already exist
                if let _ = try keychain.load("bond.secretKey") {
                    return
                }

                // Generate new key pair
                let keyPair = try bondCrypto.generateKeyPair()
                try keychain.save("bond.publicKey", keyPair.publicKey)
                try keychain.save("bond.secretKey", keyPair.secretKey)

                // Upload public key to server
                let anonID = anonymousID.getID()
                let publicKeyBase64 = keyPair.publicKey.base64EncodedString()
                let endpoint = Endpoint.uploadPublicKey(
                    anonymousID: anonID,
                    body: UploadPublicKeyRequest(publicKey: publicKeyBase64)
                )
                try await api.send(endpoint)
            },
            getPublicKey: {
                guard let publicKey = try keychain.load("bond.publicKey") else {
                    throw BondLocalError.missingPublicKey
                }
                return publicKey
            },
            createBond: { partnerID in
                let anonID = anonymousID.getID()
                let endpoint = Endpoint.createBond(
                    anonymousID: anonID,
                    body: CreateBondRequest(recipientAnonymousId: partnerID)
                )
                let response: BondResponse = try await api.send(endpoint)
                return BondInfo(
                    id: response.bondId,
                    partnerID: partnerID,
                    status: BondStatus(rawValue: response.status) ?? .pending,
                    createdAt: Date()
                )
            },
            acceptBond: { bondID in
                let anonID = anonymousID.getID()
                let endpoint = Endpoint.acceptBond(anonymousID: anonID, bondID: bondID)
                let response: BondResponse = try await api.send(endpoint)
                // Determine partner: whichever side is not us
                let partnerID = response.initiatorAnonymousId == anonID
                    ? response.recipientAnonymousId
                    : response.initiatorAnonymousId
                return BondInfo(
                    id: response.bondId,
                    partnerID: partnerID,
                    status: BondStatus(rawValue: response.status) ?? .active,
                    createdAt: Date()
                )
            },
            getMyBonds: {
                let anonID = anonymousID.getID()
                let endpoint = Endpoint.getMyBonds(anonymousID: anonID)
                let responses: [BondResponse] = try await api.send(endpoint)
                return responses.map { response in
                    let partnerID = response.initiatorAnonymousId == anonID
                        ? response.recipientAnonymousId
                        : response.initiatorAnonymousId
                    return BondInfo(
                        id: response.bondId,
                        partnerID: partnerID,
                        status: BondStatus(rawValue: response.status) ?? .pending,
                        createdAt: Date()
                    )
                }
            },
            revokeBond: { bondID in
                let anonID = anonymousID.getID()
                let endpoint = Endpoint.revokeBond(anonymousID: anonID, bondID: bondID)
                try await api.send(endpoint)
            },
            uploadSummary: { bondID, summary in
                let anonID = anonymousID.getID()

                // Get the bond to find partner ID
                let bonds: [BondResponse] = try await api.send(
                    Endpoint.getMyBonds(anonymousID: anonID)
                )
                guard let bond = bonds.first(where: { $0.bondId == bondID }) else {
                    throw BondLocalError.missingKeys
                }
                let partnerID = bond.initiatorAnonymousId == anonID
                    ? bond.recipientAnonymousId
                    : bond.initiatorAnonymousId

                // Get partner's public key
                let pubKeyResponse: PublicKeyResponse = try await api.send(
                    Endpoint.getPublicKey(anonymousID: partnerID)
                )
                guard let partnerPublicKey = Data(base64Encoded: pubKeyResponse.publicKey) else {
                    throw BondLocalError.invalidBase64
                }

                // Encode summary as JSON
                let jsonData = try JSONEncoder().encode(summary)

                // Encrypt with partner's public key
                let encryptedData = try bondCrypto.encrypt(jsonData, partnerPublicKey)
                let encryptedBase64 = encryptedData.base64EncodedString()

                // Upload blob
                let uploadEndpoint = Endpoint.uploadBlob(
                    anonymousID: anonID,
                    bondID: bondID,
                    body: UploadBlobRequest(blobType: "summary", encryptedData: encryptedBase64)
                )
                try await api.send(uploadEndpoint)
            },
            downloadPartnerSummary: { bondID in
                let anonID = anonymousID.getID()

                // Download blobs
                let blobs: [BlobResponse] = try await api.send(
                    Endpoint.getBlobs(anonymousID: anonID, bondID: bondID, blobType: "summary")
                )

                guard let blob = blobs.first else {
                    return nil
                }

                // Base64 decode the encrypted data
                guard let encryptedData = Data(base64Encoded: blob.encryptedData) else {
                    throw BondLocalError.invalidBase64
                }

                // Load our keys for decryption
                guard let publicKey = try keychain.load("bond.publicKey") else {
                    throw BondLocalError.missingPublicKey
                }
                guard let secretKey = try keychain.load("bond.secretKey") else {
                    throw BondLocalError.missingSecretKey
                }

                // Decrypt
                let decryptedData = try bondCrypto.decrypt(encryptedData, publicKey, secretKey)

                // Decode JSON
                return try JSONDecoder().decode(BondSummary.self, from: decryptedData)
            },
            backupKey: { password in
                let anonID = anonymousID.getID()

                // Load both keys
                guard let publicKey = try keychain.load("bond.publicKey") else {
                    throw BondLocalError.missingPublicKey
                }
                guard let secretKey = try keychain.load("bond.secretKey") else {
                    throw BondLocalError.missingSecretKey
                }

                // Concatenate public (32 bytes) + secret (32 bytes) = 64 bytes
                var combined = Data()
                combined.append(publicKey)
                combined.append(secretKey)

                // Encrypt with password
                let encryptedKey = try bondCrypto.encryptKeyForRecovery(combined, password)
                let encryptedBase64 = encryptedKey.base64EncodedString()

                // Upload
                let endpoint = Endpoint.uploadKeyRecovery(
                    anonymousID: anonID,
                    body: UploadKeyRecoveryRequest(encryptedRecoveryKey: encryptedBase64)
                )
                try await api.send(endpoint)
            },
            restoreKey: { password in
                let anonID = anonymousID.getID()

                // Download encrypted recovery key
                let response: KeyRecoveryResponse = try await api.send(
                    Endpoint.getKeyRecovery(anonymousID: anonID)
                )

                // Base64 decode
                guard let encryptedData = Data(base64Encoded: response.encryptedRecoveryKey) else {
                    throw BondLocalError.invalidBase64
                }

                // Decrypt with password
                let combined = try bondCrypto.decryptKeyFromRecovery(encryptedData, password)

                // Split: first 32 bytes = public key, last 32 bytes = secret key
                guard combined.count == 64 else {
                    throw BondLocalError.invalidRecoveryData
                }
                let publicKey = combined.prefix(32)
                let secretKey = combined.suffix(32)

                // Save both to Keychain
                try keychain.save("bond.publicKey", Data(publicKey))
                try keychain.save("bond.secretKey", Data(secretKey))

                // Re-upload public key to server
                let publicKeyBase64 = Data(publicKey).base64EncodedString()
                let uploadEndpoint = Endpoint.uploadPublicKey(
                    anonymousID: anonID,
                    body: UploadPublicKeyRequest(publicKey: publicKeyBase64)
                )
                try await api.send(uploadEndpoint)
            }
        )
    }
}

extension BondLocalClient: DependencyKey {
    public static let liveValue = BondLocalClient.live()

    public static let testValue = BondLocalClient(
        initializeKeys: { },
        getPublicKey: { Data(repeating: 0xAA, count: 32) },
        createBond: { id in BondInfo(id: "test", partnerID: id, status: .pending, createdAt: Date()) },
        acceptBond: { id in BondInfo(id: id, partnerID: "p", status: .active, createdAt: Date()) },
        getMyBonds: { [] },
        revokeBond: { _ in },
        uploadSummary: { _, _ in },
        downloadPartnerSummary: { _ in nil },
        backupKey: { _ in },
        restoreKey: { _ in }
    )
}

extension DependencyValues {
    public var bondLocal: BondLocalClient {
        get { self[BondLocalClient.self] }
        set { self[BondLocalClient.self] = newValue }
    }
}
