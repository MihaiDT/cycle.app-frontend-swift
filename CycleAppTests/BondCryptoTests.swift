@testable import CycleApp
import Testing
import Foundation

@Suite("Bond Crypto Tests")
struct BondCryptoTests {

    @Test("Key pair generation")
    func generateKeys() throws {
        let crypto = BondCryptoManager.liveValue
        let keys = try crypto.generateKeyPair()
        #expect(keys.publicKey.count == 32)
        #expect(keys.secretKey.count == 32)
        print("✅ Keys generated: pub=\(keys.publicKey.count)b, sec=\(keys.secretKey.count)b")
    }

    @Test("Sealed Box encrypt/decrypt round-trip")
    func encryptDecrypt() throws {
        let crypto = BondCryptoManager.liveValue
        let keys = try crypto.generateKeyPair()

        let message = "Hello Bond! 🔐".data(using: .utf8)!
        let encrypted = try crypto.encrypt(message, keys.publicKey)
        #expect(encrypted.count > message.count)

        let decrypted = try crypto.decrypt(encrypted, keys.publicKey, keys.secretKey)
        let text = String(data: decrypted, encoding: .utf8)
        #expect(text == "Hello Bond! 🔐")
        print("✅ Encrypt/decrypt round-trip passed")
    }

    @Test("BondSummary encrypt/decrypt")
    func bondSummaryRoundTrip() throws {
        let crypto = BondCryptoManager.liveValue
        let keys = try crypto.generateKeyPair()

        let summary = BondSummary(
            cyclePhase: "follicular",
            energyLevel: 4,
            moodLevel: 3,
            dominantElement: "water",
            tensionScore: 0.6
        )
        let data = try JSONEncoder().encode(summary)
        let encrypted = try crypto.encrypt(data, keys.publicKey)
        let decrypted = try crypto.decrypt(encrypted, keys.publicKey, keys.secretKey)
        let decoded = try JSONDecoder().decode(BondSummary.self, from: decrypted)

        #expect(decoded.cyclePhase == "follicular")
        #expect(decoded.energyLevel == 4)
        print("✅ BondSummary round-trip passed")
    }

    @Test("Key recovery with password")
    func keyRecovery() throws {
        let crypto = BondCryptoManager.liveValue
        let keys = try crypto.generateKeyPair()
        let combined = keys.publicKey + keys.secretKey

        let password = "testPassword123!"
        let encrypted = try crypto.encryptKeyForRecovery(combined, password)
        #expect(encrypted.count > combined.count)
        print("Encrypted recovery blob: \(encrypted.count) bytes")

        let recovered = try crypto.decryptKeyFromRecovery(encrypted, password)
        #expect(recovered == combined)
        print("✅ Key recovery round-trip passed")
    }

    @Test("Wrong password fails")
    func wrongPasswordFails() throws {
        let crypto = BondCryptoManager.liveValue
        let keys = try crypto.generateKeyPair()
        let combined = keys.publicKey + keys.secretKey

        let encrypted = try crypto.encryptKeyForRecovery(combined, "correctPassword")

        #expect(throws: BondCryptoError.self) {
            _ = try crypto.decryptKeyFromRecovery(encrypted, "wrongPassword")
        }
        print("✅ Wrong password correctly rejected")
    }

    @Test("Two users encrypt for each other")
    func twoUserEncryption() throws {
        let crypto = BondCryptoManager.liveValue

        // User A generates keys
        let keysA = try crypto.generateKeyPair()
        // User B generates keys
        let keysB = try crypto.generateKeyPair()

        // User A encrypts for User B
        let messageA = "From A to B".data(using: .utf8)!
        let encryptedForB = try crypto.encrypt(messageA, keysB.publicKey)

        // User B decrypts
        let decryptedByB = try crypto.decrypt(encryptedForB, keysB.publicKey, keysB.secretKey)
        #expect(String(data: decryptedByB, encoding: .utf8) == "From A to B")

        // User B encrypts for User A
        let messageB = "From B to A".data(using: .utf8)!
        let encryptedForA = try crypto.encrypt(messageB, keysA.publicKey)

        // User A decrypts
        let decryptedByA = try crypto.decrypt(encryptedForA, keysA.publicKey, keysA.secretKey)
        #expect(String(data: decryptedByA, encoding: .utf8) == "From B to A")

        print("✅ Two-user encryption round-trip passed")
    }
}
