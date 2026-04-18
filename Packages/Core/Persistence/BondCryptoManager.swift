import ComposableArchitecture
import Foundation
import Sodium

// MARK: - Bond Crypto Manager

public struct BondCryptoManager: Sendable {
    public var generateKeyPair: @Sendable () throws -> (publicKey: Data, secretKey: Data)
    public var encrypt: @Sendable (_ message: Data, _ recipientPublicKey: Data) throws -> Data
    public var decrypt: @Sendable (_ encrypted: Data, _ publicKey: Data, _ secretKey: Data) throws -> Data
    public var encryptKeyForRecovery: @Sendable (_ secretKey: Data, _ password: String) throws -> Data
    public var decryptKeyFromRecovery: @Sendable (_ encryptedKey: Data, _ password: String) throws -> Data
}

// MARK: - Errors

public enum BondCryptoError: Error, Sendable {
    case keyGenerationFailed
    case encryptionFailed
    case decryptionFailed
    case invalidKeyLength
    case passwordDerivationFailed
}

// MARK: - Dependency

extension BondCryptoManager: DependencyKey {
    public static let liveValue: BondCryptoManager = {
        nonisolated(unsafe) let sodium = Sodium()
        return BondCryptoManager(
            generateKeyPair: {
                guard let keyPair = sodium.box.keyPair() else {
                    throw BondCryptoError.keyGenerationFailed
                }
                return (publicKey: Data(keyPair.publicKey), secretKey: Data(keyPair.secretKey))
            },
            encrypt: { message, recipientPublicKey in
                guard let encrypted = sodium.box.seal(
                    message: Array(message),
                    recipientPublicKey: Array(recipientPublicKey)
                ) else {
                    throw BondCryptoError.encryptionFailed
                }
                return Data(encrypted)
            },
            decrypt: { encrypted, publicKey, secretKey in
                guard let decrypted = sodium.box.open(
                    anonymousCipherText: Array(encrypted),
                    recipientPublicKey: Array(publicKey),
                    recipientSecretKey: Array(secretKey)
                ) else {
                    throw BondCryptoError.decryptionFailed
                }
                return Data(decrypted)
            },
            encryptKeyForRecovery: { secretKey, password in
                let salt = sodium.randomBytes.buf(length: sodium.pwHash.SaltBytes)!
                guard let derivedKey = sodium.pwHash.hash(
                    outputLength: sodium.secretBox.KeyBytes,
                    passwd: Array(password.utf8),
                    salt: salt,
                    opsLimit: sodium.pwHash.OpsLimitModerate,
                    memLimit: sodium.pwHash.MemLimitModerate
                ) else {
                    throw BondCryptoError.passwordDerivationFailed
                }
                guard let encrypted = sodium.secretBox.seal(
                    message: Array(secretKey),
                    secretKey: derivedKey
                ) else {
                    throw BondCryptoError.encryptionFailed
                }
                return Data(salt + encrypted)
            },
            decryptKeyFromRecovery: { encryptedKey, password in
                let bytes = Array(encryptedKey)
                let saltLength = sodium.pwHash.SaltBytes
                guard bytes.count > saltLength else {
                    throw BondCryptoError.invalidKeyLength
                }
                let salt = Array(bytes.prefix(saltLength))
                let encrypted = Array(bytes.dropFirst(saltLength))
                guard let derivedKey = sodium.pwHash.hash(
                    outputLength: sodium.secretBox.KeyBytes,
                    passwd: Array(password.utf8),
                    salt: salt,
                    opsLimit: sodium.pwHash.OpsLimitModerate,
                    memLimit: sodium.pwHash.MemLimitModerate
                ) else {
                    throw BondCryptoError.passwordDerivationFailed
                }
                guard let decrypted = sodium.secretBox.open(
                    authenticatedCipherText: encrypted,
                    secretKey: derivedKey
                ) else {
                    throw BondCryptoError.decryptionFailed
                }
                return Data(decrypted)
            }
        )
    }()

    public static let testValue = BondCryptoManager(
        generateKeyPair: { (publicKey: Data(repeating: 0xAA, count: 32), secretKey: Data(repeating: 0xBB, count: 32)) },
        encrypt: { message, _ in message },
        decrypt: { encrypted, _, _ in encrypted },
        encryptKeyForRecovery: { secretKey, _ in secretKey },
        decryptKeyFromRecovery: { encrypted, _ in encrypted }
    )

    public static let previewValue = BondCryptoManager(
        generateKeyPair: { (publicKey: Data(repeating: 0xAA, count: 32), secretKey: Data(repeating: 0xBB, count: 32)) },
        encrypt: { message, _ in message },
        decrypt: { encrypted, _, _ in encrypted },
        encryptKeyForRecovery: { secretKey, _ in secretKey },
        decryptKeyFromRecovery: { encrypted, _ in encrypted }
    )
}

extension DependencyValues {
    public var bondCrypto: BondCryptoManager {
        get { self[BondCryptoManager.self] }
        set { self[BondCryptoManager.self] = newValue }
    }
}
