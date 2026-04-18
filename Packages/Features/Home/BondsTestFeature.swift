import ComposableArchitecture
import SwiftUI

// MARK: - Bonds Test Feature (temporary, for testing crypto + API)

@Reducer
public struct BondsTestFeature: Sendable {
    @ObservableState
    public struct State: Equatable, Sendable {
        public var log: [String] = []
        public var isRunning: Bool = false
        public var publicKeyHex: String = ""
        public var encryptedHex: String = ""
        public var decryptedText: String = ""
        public var bonds: [BondInfo] = []
        public var myAnonymousID: String = ""
        public var partnerIDInput: String = ""
        public var activeBondID: String = ""
        public var pendingBondID: String = ""

        public init() {}
    }

    public enum Action: BindableAction, Sendable {
        case binding(BindingAction<State>)
        case testCryptoTapped
        case testKeyRecoveryTapped
        case initializeKeysTapped
        case fetchBondsTapped
        case createTestBondTapped
        case fullE2ETestTapped
        case onAppear
        case realCreateBondTapped
        case realAcceptBondTapped
        case realUploadSummaryTapped
        case realDownloadPartnerTapped
        case realFetchPendingTapped
        case appendLog(String)
    }

    @Dependency(\.bondCrypto) var bondCrypto
    @Dependency(\.bondLocal) var bondLocal
    @Dependency(\.keychainClient) var keychain
    @Dependency(\.apiClient) var api
    @Dependency(\.anonymousID) var anonymousID

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            // MARK: - On Appear
            case .onAppear:
                state.myAnonymousID = anonymousID.getID()
                return .none

            // MARK: - Real 2-device flow
            case .realCreateBondTapped:
                let partnerID = state.partnerIDInput.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !partnerID.isEmpty else {
                    state.log.append("❌ Enter partner's ID first")
                    return .none
                }
                state.isRunning = true
                return .run { [bondCrypto, anonymousID] send in
                    let base = "https://dth-backend-277319586889.us-central1.run.app"
                    let myID = anonymousID.getID()
                    do {
                        // Init keys if needed
                        let keychain = KeychainClient.live()
                        if try keychain.load("bond.publicKey") == nil {
                            await send(.appendLog("🔑 Generating keys..."))
                            let keys = try bondCrypto.generateKeyPair()
                            try keychain.save("bond.publicKey", keys.publicKey)
                            try keychain.save("bond.secretKey", keys.secretKey)
                            var req = URLRequest(url: URL(string: "\(base)/api/\(myID)/keys")!)
                            req.httpMethod = "PUT"
                            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                            req.httpBody = try JSONEncoder().encode(["public_key": keys.publicKey.base64EncodedString()])
                            _ = try await URLSession.shared.data(for: req)
                            await send(.appendLog("✅ Keys uploaded"))
                        }

                        // Create bond
                        await send(.appendLog("🔗 Creating bond with \(partnerID.prefix(12))..."))
                        var req = URLRequest(url: URL(string: "\(base)/api/\(myID)/bonds")!)
                        req.httpMethod = "POST"
                        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                        req.httpBody = try JSONEncoder().encode(["partner_id": partnerID])
                        let (data, _) = try await URLSession.shared.data(for: req)
                        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                        let bondObj = json?["bond"] as? [String: Any]
                        let bondID = bondObj?["id"] as? String ?? ""
                        await send(.appendLog("✅ Bond created: \(bondID)"))
                        await send(.appendLog("📋 Send this bond ID to your friend to accept"))
                    } catch {
                        await send(.appendLog("❌ \(error.localizedDescription)"))
                    }
                }

            case .realFetchPendingTapped:
                state.isRunning = true
                return .run { [anonymousID] send in
                    let base = "https://dth-backend-277319586889.us-central1.run.app"
                    let myID = anonymousID.getID()
                    do {
                        let (data, _) = try await URLSession.shared.data(from: URL(string: "\(base)/api/\(myID)/bonds")!)
                        let bonds = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
                        for bond in bonds {
                            let bondObj = bond["bond"] as? [String: Any] ?? bond
                            let id = bondObj["id"] as? String ?? ""
                            let status = bondObj["status"] as? String ?? ""
                            let partner = bond["partner_id"] as? String ?? ""
                            await send(.appendLog("Bond: \(id.prefix(12))... status=\(status) partner=\(partner.prefix(12))..."))
                        }
                        if bonds.isEmpty {
                            await send(.appendLog("No bonds found"))
                        }
                    } catch {
                        await send(.appendLog("❌ \(error.localizedDescription)"))
                    }
                }

            case .realAcceptBondTapped:
                let bondID = state.pendingBondID.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !bondID.isEmpty else {
                    state.log.append("❌ Enter bond ID first")
                    return .none
                }
                state.isRunning = true
                return .run { [bondCrypto, anonymousID] send in
                    let base = "https://dth-backend-277319586889.us-central1.run.app"
                    let myID = anonymousID.getID()
                    do {
                        // Init keys if needed
                        let keychain = KeychainClient.live()
                        if try keychain.load("bond.publicKey") == nil {
                            await send(.appendLog("🔑 Generating keys..."))
                            let keys = try bondCrypto.generateKeyPair()
                            try keychain.save("bond.publicKey", keys.publicKey)
                            try keychain.save("bond.secretKey", keys.secretKey)
                            var req = URLRequest(url: URL(string: "\(base)/api/\(myID)/keys")!)
                            req.httpMethod = "PUT"
                            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                            req.httpBody = try JSONEncoder().encode(["public_key": keys.publicKey.base64EncodedString()])
                            _ = try await URLSession.shared.data(for: req)
                            await send(.appendLog("✅ Keys uploaded"))
                        }

                        await send(.appendLog("✋ Accepting bond \(bondID.prefix(12))..."))
                        var req = URLRequest(url: URL(string: "\(base)/api/\(myID)/bonds/\(bondID)/accept")!)
                        req.httpMethod = "POST"
                        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                        req.httpBody = "{}".data(using: .utf8)
                        let (data, resp) = try await URLSession.shared.data(for: req)
                        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
                        await send(.appendLog("✅ Bond accepted (HTTP \(code))"))
                    } catch {
                        await send(.appendLog("❌ \(error.localizedDescription)"))
                    }
                }

            case .realUploadSummaryTapped:
                let bondID = state.activeBondID.trimmingCharacters(in: .whitespacesAndNewlines)
                let partnerID = state.partnerIDInput.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !bondID.isEmpty, !partnerID.isEmpty else {
                    state.log.append("❌ Need bond ID + partner ID")
                    return .none
                }
                state.isRunning = true
                return .run { [bondCrypto, anonymousID] send in
                    let base = "https://dth-backend-277319586889.us-central1.run.app"
                    let myID = anonymousID.getID()
                    do {
                        // Get partner's public key
                        await send(.appendLog("🔑 Getting partner's public key..."))
                        let (keyData, _) = try await URLSession.shared.data(from: URL(string: "\(base)/api/\(partnerID)/keys")!)
                        let keyJSON = try JSONSerialization.jsonObject(with: keyData) as? [String: Any]
                        guard let pubKeyB64 = keyJSON?["public_key"] as? String,
                              let partnerPubKey = Data(base64Encoded: pubKeyB64) else {
                            await send(.appendLog("❌ Partner hasn't uploaded keys yet"))
                            return
                        }

                        // Create and encrypt summary
                        let summary = BondSummary(
                            cyclePhase: "follicular",
                            energyLevel: 4,
                            moodLevel: 3,
                            dominantElement: "water",
                            tensionScore: 0.6
                        )
                        let summaryData = try JSONEncoder().encode(summary)
                        let encrypted = try bondCrypto.encrypt(summaryData, partnerPubKey)

                        // Upload
                        var req = URLRequest(url: URL(string: "\(base)/api/\(myID)/bonds/\(bondID)/blobs")!)
                        req.httpMethod = "PUT"
                        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                        req.httpBody = try JSONEncoder().encode([
                            "blob_data": encrypted.base64EncodedString(),
                            "blob_type": "summary"
                        ])
                        let (_, resp) = try await URLSession.shared.data(for: req)
                        await send(.appendLog("✅ Summary encrypted & uploaded (HTTP \((resp as? HTTPURLResponse)?.statusCode ?? 0))"))
                    } catch {
                        await send(.appendLog("❌ \(error.localizedDescription)"))
                    }
                }

            case .realDownloadPartnerTapped:
                let bondID = state.activeBondID.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !bondID.isEmpty else {
                    state.log.append("❌ Need bond ID")
                    return .none
                }
                state.isRunning = true
                return .run { [bondCrypto, anonymousID] send in
                    let base = "https://dth-backend-277319586889.us-central1.run.app"
                    let myID = anonymousID.getID()
                    do {
                        let keychain = KeychainClient.live()
                        guard let myPubKey = try keychain.load("bond.publicKey"),
                              let mySecKey = try keychain.load("bond.secretKey") else {
                            await send(.appendLog("❌ No keys found — initialize first"))
                            return
                        }

                        await send(.appendLog("📡 Downloading blobs..."))
                        let (data, _) = try await URLSession.shared.data(from: URL(string: "\(base)/api/\(myID)/bonds/\(bondID)/blobs?type=summary")!)
                        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

                        guard let partnerB64 = json?["partner_blob"] as? String,
                              let partnerBlob = Data(base64Encoded: partnerB64) else {
                            await send(.appendLog("⚠️ Partner hasn't uploaded a summary yet"))
                            return
                        }

                        let decrypted = try bondCrypto.decrypt(partnerBlob, myPubKey, mySecKey)
                        let summary = try JSONDecoder().decode(BondSummary.self, from: decrypted)
                        await send(.appendLog("✅ Partner's summary:"))
                        await send(.appendLog("   Phase: \(summary.cyclePhase)"))
                        await send(.appendLog("   Energy: \(summary.energyLevel), Mood: \(summary.moodLevel)"))
                        await send(.appendLog("   Element: \(summary.dominantElement)"))
                        await send(.appendLog("🎉 Decryption successful!"))
                    } catch {
                        await send(.appendLog("❌ \(error.localizedDescription)"))
                    }
                }

            // MARK: - Test local crypto (no server needed)
            case .testCryptoTapped:
                state.isRunning = true
                state.log = []
                return .run { send in
                    await send(.appendLog("🔑 Generating key pair..."))
                    do {
                        let keys = try bondCrypto.generateKeyPair()
                        await send(.appendLog("✅ Public key: \(keys.publicKey.prefix(16).map { String(format: "%02x", $0) }.joined())..."))
                        await send(.appendLog("✅ Secret key: \(keys.secretKey.prefix(8).map { String(format: "%02x", $0) }.joined())... (hidden)"))

                        // Test encrypt
                        let testMessage = "Hello from Bond! 🔐".data(using: .utf8)!
                        await send(.appendLog("📦 Encrypting: \"Hello from Bond! 🔐\""))
                        let encrypted = try bondCrypto.encrypt(testMessage, keys.publicKey)
                        await send(.appendLog("✅ Encrypted: \(encrypted.count) bytes"))

                        // Test decrypt
                        await send(.appendLog("🔓 Decrypting..."))
                        let decrypted = try bondCrypto.decrypt(encrypted, keys.publicKey, keys.secretKey)
                        let text = String(data: decrypted, encoding: .utf8) ?? "???"
                        await send(.appendLog("✅ Decrypted: \"\(text)\""))

                        if text == "Hello from Bond! 🔐" {
                            await send(.appendLog("🎉 CRYPTO TEST PASSED — encrypt/decrypt round-trip works!"))
                        } else {
                            await send(.appendLog("❌ MISMATCH — decrypted text doesn't match"))
                        }

                        // Test with BondSummary
                        let summary = BondSummary(
                            cyclePhase: "follicular",
                            energyLevel: 4,
                            moodLevel: 3,
                            dominantElement: "water",
                            tensionScore: 0.6
                        )
                        let summaryData = try JSONEncoder().encode(summary)
                        await send(.appendLog("📦 Encrypting BondSummary (\(summaryData.count) bytes)..."))

                        let encSummary = try bondCrypto.encrypt(summaryData, keys.publicKey)
                        let decSummary = try bondCrypto.decrypt(encSummary, keys.publicKey, keys.secretKey)
                        let decoded = try JSONDecoder().decode(BondSummary.self, from: decSummary)
                        await send(.appendLog("✅ BondSummary round-trip: phase=\(decoded.cyclePhase), energy=\(decoded.energyLevel)"))
                        await send(.appendLog("🎉 FULL CRYPTO TEST PASSED!"))

                    } catch {
                        await send(.appendLog("❌ Error: \(error.localizedDescription)"))
                    }
                }

            // MARK: - Test key recovery (no server needed)
            case .testKeyRecoveryTapped:
                state.isRunning = true
                return .run { send in
                    await send(.appendLog("🔐 Testing key recovery..."))
                    do {
                        let keys = try bondCrypto.generateKeyPair()
                        let combined = keys.publicKey + keys.secretKey
                        await send(.appendLog("📦 Original keys: \(combined.count) bytes"))

                        let password = "testPassword123!"
                        await send(.appendLog("🔒 Encrypting with password..."))
                        let encrypted = try bondCrypto.encryptKeyForRecovery(combined, password)
                        await send(.appendLog("✅ Encrypted recovery blob: \(encrypted.count) bytes"))

                        await send(.appendLog("🔓 Decrypting with password..."))
                        let recovered = try bondCrypto.decryptKeyFromRecovery(encrypted, password)
                        await send(.appendLog("✅ Recovered: \(recovered.count) bytes"))

                        if recovered == combined {
                            await send(.appendLog("🎉 KEY RECOVERY TEST PASSED!"))
                        } else {
                            await send(.appendLog("❌ MISMATCH — recovered keys don't match"))
                        }

                        // Test wrong password
                        await send(.appendLog("🔓 Testing wrong password..."))
                        do {
                            _ = try bondCrypto.decryptKeyFromRecovery(encrypted, "wrongPassword")
                            await send(.appendLog("❌ Should have failed with wrong password!"))
                        } catch {
                            await send(.appendLog("✅ Correctly rejected wrong password: \(error)"))
                        }

                    } catch {
                        await send(.appendLog("❌ Error: \(error.localizedDescription)"))
                    }
                }

            // MARK: - Initialize keys (needs server for upload)
            case .initializeKeysTapped:
                state.isRunning = true
                return .run { send in
                    await send(.appendLog("🔑 Initializing keys..."))
                    do {
                        try await bondLocal.initializeKeys()
                        let pubKey = try bondLocal.getPublicKey()
                        await send(.appendLog("✅ Keys initialized! Public key: \(pubKey.prefix(16).map { String(format: "%02x", $0) }.joined())..."))
                    } catch {
                        await send(.appendLog("⚠️ Keys generated locally but server upload failed: \(error.localizedDescription)"))
                        await send(.appendLog("(This is expected if server isn't running)"))
                    }
                }

            // MARK: - Fetch bonds (needs server)
            case .fetchBondsTapped:
                state.isRunning = true
                return .run { send in
                    await send(.appendLog("📡 Fetching bonds from server..."))
                    do {
                        let bonds = try await bondLocal.getMyBonds()
                        await send(.appendLog("✅ Found \(bonds.count) bonds"))
                        for bond in bonds {
                            await send(.appendLog("  • \(bond.id.prefix(8))... — \(bond.status.rawValue)"))
                        }
                    } catch {
                        await send(.appendLog("❌ Server error: \(error.localizedDescription)"))
                    }
                }

            // MARK: - Create test bond (needs server)
            case .createTestBondTapped:
                state.isRunning = true
                return .run { send in
                    await send(.appendLog("📡 Creating test bond..."))
                    do {
                        let bond = try await bondLocal.createBond("test-partner-id")
                        await send(.appendLog("✅ Bond created: \(bond.id.prefix(8))... status=\(bond.status.rawValue)"))
                    } catch {
                        await send(.appendLog("❌ Server error: \(error.localizedDescription)"))
                    }
                }

            // MARK: - Full E2E Test (simulates 2 users, bond, encrypt, exchange, decrypt)
            case .fullE2ETestTapped:
                state.isRunning = true
                state.log = []
                return .run { [bondCrypto, api, anonymousID] send in
                    do {
                        let baseURL = "https://dth-backend-277319586889.us-central1.run.app"

                        // === STEP 1: Generate keys for User A (us) ===
                        await send(.appendLog("👤 STEP 1: Generating keys for User A (you)..."))
                        let keysA = try bondCrypto.generateKeyPair()
                        let myAnonID = anonymousID.getID()
                        await send(.appendLog("   ID: \(myAnonID.prefix(12))..."))
                        await send(.appendLog("   PubKey: \(keysA.publicKey.prefix(8).map { String(format: "%02x", $0) }.joined())..."))

                        // Upload User A public key
                        var reqA = URLRequest(url: URL(string: "\(baseURL)/api/\(myAnonID)/keys")!)
                        reqA.httpMethod = "PUT"
                        reqA.setValue("application/json", forHTTPHeaderField: "Content-Type")
                        reqA.httpBody = try JSONEncoder().encode(["public_key": keysA.publicKey.base64EncodedString()])
                        let (_, respA) = try await URLSession.shared.data(for: reqA)
                        await send(.appendLog("   ✅ Uploaded public key (HTTP \((respA as? HTTPURLResponse)?.statusCode ?? 0))"))

                        // === STEP 2: Generate keys for User B (simulated friend) ===
                        await send(.appendLog("👥 STEP 2: Generating keys for User B (friend)..."))
                        let keysB = try bondCrypto.generateKeyPair()
                        let friendID = UUID().uuidString.lowercased()
                        await send(.appendLog("   ID: \(friendID.prefix(12))..."))

                        // Upload User B public key
                        var reqB = URLRequest(url: URL(string: "\(baseURL)/api/\(friendID)/keys")!)
                        reqB.httpMethod = "PUT"
                        reqB.setValue("application/json", forHTTPHeaderField: "Content-Type")
                        reqB.httpBody = try JSONEncoder().encode(["public_key": keysB.publicKey.base64EncodedString()])
                        let (_, respB) = try await URLSession.shared.data(for: reqB)
                        await send(.appendLog("   ✅ Uploaded friend's public key (HTTP \((respB as? HTTPURLResponse)?.statusCode ?? 0))"))

                        // === STEP 3: Create bond A → B ===
                        await send(.appendLog("🔗 STEP 3: Creating bond..."))
                        var reqBond = URLRequest(url: URL(string: "\(baseURL)/api/\(myAnonID)/bonds")!)
                        reqBond.httpMethod = "POST"
                        reqBond.setValue("application/json", forHTTPHeaderField: "Content-Type")
                        reqBond.httpBody = try JSONEncoder().encode(["partner_id": friendID])
                        let (bondData, _) = try await URLSession.shared.data(for: reqBond)
                        let bondJSON = try JSONSerialization.jsonObject(with: bondData) as? [String: Any]
                        let bondObj = bondJSON?["bond"] as? [String: Any]
                        let bondID = bondObj?["id"] as? String ?? ""
                        await send(.appendLog("   ✅ Bond created: \(bondID.prefix(12))... (pending)"))

                        // === STEP 4: Accept bond as User B ===
                        await send(.appendLog("✋ STEP 4: Friend accepts bond..."))
                        var reqAccept = URLRequest(url: URL(string: "\(baseURL)/api/\(friendID)/bonds/\(bondID)/accept")!)
                        reqAccept.httpMethod = "POST"
                        reqAccept.setValue("application/json", forHTTPHeaderField: "Content-Type")
                        reqAccept.httpBody = "{}".data(using: .utf8)
                        let (_, respAccept) = try await URLSession.shared.data(for: reqAccept)
                        await send(.appendLog("   ✅ Bond accepted (HTTP \((respAccept as? HTTPURLResponse)?.statusCode ?? 0))"))

                        // === STEP 5: User A encrypts summary for User B ===
                        await send(.appendLog("📦 STEP 5: Encrypting your summary for friend..."))
                        let summaryA = BondSummary(
                            cyclePhase: "follicular",
                            energyLevel: 4,
                            moodLevel: 3,
                            dominantElement: "water",
                            tensionScore: 0.6
                        )
                        let summaryDataA = try JSONEncoder().encode(summaryA)
                        let encryptedForB = try bondCrypto.encrypt(summaryDataA, keysB.publicKey)
                        await send(.appendLog("   Encrypted: \(encryptedForB.count) bytes"))

                        // Upload blob as User A
                        var reqBlobA = URLRequest(url: URL(string: "\(baseURL)/api/\(myAnonID)/bonds/\(bondID)/blobs")!)
                        reqBlobA.httpMethod = "PUT"
                        reqBlobA.setValue("application/json", forHTTPHeaderField: "Content-Type")
                        reqBlobA.httpBody = try JSONEncoder().encode([
                            "blob_data": encryptedForB.base64EncodedString(),
                            "blob_type": "summary"
                        ])
                        let (_, respBlobA) = try await URLSession.shared.data(for: reqBlobA)
                        await send(.appendLog("   ✅ Uploaded your encrypted summary (HTTP \((respBlobA as? HTTPURLResponse)?.statusCode ?? 0))"))

                        // === STEP 6: User B encrypts summary for User A ===
                        await send(.appendLog("📦 STEP 6: Friend encrypts summary for you..."))
                        let summaryB = BondSummary(
                            cyclePhase: "luteal",
                            energyLevel: 2,
                            moodLevel: 2,
                            dominantElement: "fire",
                            tensionScore: 0.8
                        )
                        let summaryDataB = try JSONEncoder().encode(summaryB)
                        let encryptedForA = try bondCrypto.encrypt(summaryDataB, keysA.publicKey)

                        // Upload blob as User B
                        var reqBlobB = URLRequest(url: URL(string: "\(baseURL)/api/\(friendID)/bonds/\(bondID)/blobs")!)
                        reqBlobB.httpMethod = "PUT"
                        reqBlobB.setValue("application/json", forHTTPHeaderField: "Content-Type")
                        reqBlobB.httpBody = try JSONEncoder().encode([
                            "blob_data": encryptedForA.base64EncodedString(),
                            "blob_type": "summary"
                        ])
                        let (_, respBlobB) = try await URLSession.shared.data(for: reqBlobB)
                        await send(.appendLog("   ✅ Friend uploaded encrypted summary (HTTP \((respBlobB as? HTTPURLResponse)?.statusCode ?? 0))"))

                        // === STEP 7: User A downloads and decrypts User B's summary ===
                        await send(.appendLog("🔓 STEP 7: Downloading & decrypting friend's summary..."))
                        var reqGet = URLRequest(url: URL(string: "\(baseURL)/api/\(myAnonID)/bonds/\(bondID)/blobs?type=summary")!)
                        reqGet.httpMethod = "GET"
                        let (blobsData, _) = try await URLSession.shared.data(for: reqGet)
                        let blobsJSON = try JSONSerialization.jsonObject(with: blobsData) as? [String: Any]

                        guard let partnerBlobB64 = blobsJSON?["partner_blob"] as? String,
                              let partnerBlobData = Data(base64Encoded: partnerBlobB64) else {
                            await send(.appendLog("   ❌ No partner blob found"))
                            return
                        }
                        await send(.appendLog("   Downloaded: \(partnerBlobData.count) encrypted bytes"))

                        let decryptedB = try bondCrypto.decrypt(partnerBlobData, keysA.publicKey, keysA.secretKey)
                        let decodedB = try JSONDecoder().decode(BondSummary.self, from: decryptedB)
                        await send(.appendLog("   ✅ Decrypted friend's summary:"))
                        await send(.appendLog("      Phase: \(decodedB.cyclePhase)"))
                        await send(.appendLog("      Energy: \(decodedB.energyLevel), Mood: \(decodedB.moodLevel)"))
                        await send(.appendLog("      Element: \(decodedB.dominantElement)"))

                        // === VERIFY ===
                        if decodedB.cyclePhase == "luteal" && decodedB.energyLevel == 2 && decodedB.dominantElement == "fire" {
                            await send(.appendLog(""))
                            await send(.appendLog("🎉🎉🎉 FULL E2E TEST PASSED! 🎉🎉🎉"))
                            await send(.appendLog(""))
                            await send(.appendLog("✅ Keys generated on device"))
                            await send(.appendLog("✅ Public keys uploaded to server"))
                            await send(.appendLog("✅ Bond created & accepted"))
                            await send(.appendLog("✅ Data encrypted client-side"))
                            await send(.appendLog("✅ Encrypted blobs stored on server"))
                            await send(.appendLog("✅ Blobs downloaded & decrypted"))
                            await send(.appendLog("✅ Original data recovered perfectly"))
                            await send(.appendLog("✅ Server never saw plaintext!"))
                        } else {
                            await send(.appendLog("❌ DATA MISMATCH — decrypted doesn't match original"))
                        }

                    } catch {
                        await send(.appendLog("❌ Error: \(error)"))
                    }
                }

            case let .appendLog(message):
                state.log.append(message)
                state.isRunning = false
                return .none
            }
        }
    }
}

// MARK: - Test View

struct BondsTestView: View {
    @Bindable var store: StoreOf<BondsTestFeature>

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Your ID
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your Anonymous ID:")
                                .font(.raleway("SemiBold", size: 13, relativeTo: .caption))
                                .foregroundStyle(DesignColors.textSecondary)
                            Text(store.myAnonymousID)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(DesignColors.text)
                                .textSelection(.enabled)
                            Button("Copy") {
                                UIPasteboard.general.string = store.myAnonymousID
                            }
                            .font(.raleway("SemiBold", size: 13, relativeTo: .caption))
                            .foregroundStyle(DesignColors.accentWarm)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(.white))
                        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                    } header: {
                        sectionHeader("Your Device")
                    }

                    Divider()

                    // Real 2-device test
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Step 1: Initialize keys")
                                .font(.raleway("SemiBold", size: 14, relativeTo: .body))
                                .foregroundStyle(DesignColors.text)
                            testButton("🔑 Initialize Keys", action: .initializeKeysTapped)

                            Divider()

                            Text("Step 2: Enter partner's ID")
                                .font(.raleway("SemiBold", size: 14, relativeTo: .body))
                                .foregroundStyle(DesignColors.text)
                            TextField("Partner Anonymous ID", text: $store.partnerIDInput)
                                .font(.system(size: 13, design: .monospaced))
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)

                            Divider()

                            Text("Step 3: Create bond (Phone A does this)")
                                .font(.raleway("SemiBold", size: 14, relativeTo: .body))
                                .foregroundStyle(DesignColors.text)
                            testButton("🔗 Create Bond", action: .realCreateBondTapped)

                            Divider()

                            Text("Step 4: Check pending bonds")
                                .font(.raleway("SemiBold", size: 14, relativeTo: .body))
                                .foregroundStyle(DesignColors.text)
                            testButton("📋 List My Bonds", action: .realFetchPendingTapped)

                            Divider()

                            Text("Step 5: Accept bond (Phone B does this)")
                                .font(.raleway("SemiBold", size: 14, relativeTo: .body))
                                .foregroundStyle(DesignColors.text)
                            TextField("Bond ID to accept", text: $store.pendingBondID)
                                .font(.system(size: 13, design: .monospaced))
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                            testButton("✋ Accept Bond", action: .realAcceptBondTapped)

                            Divider()

                            Text("Step 6: Exchange data")
                                .font(.raleway("SemiBold", size: 14, relativeTo: .body))
                                .foregroundStyle(DesignColors.text)
                            TextField("Active Bond ID", text: $store.activeBondID)
                                .font(.system(size: 13, design: .monospaced))
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                            testButton("📤 Upload My Summary", action: .realUploadSummaryTapped)
                            testButton("📥 Download Partner's Summary", action: .realDownloadPartnerTapped)
                        }
                    } header: {
                        sectionHeader("Real 2-Device Test")
                    }

                    Divider()

                    // Automated test
                    Section {
                        testButton("🚀 Full E2E Test (simulated)", action: .fullE2ETestTapped)
                        testButton("🔐 Test Crypto (local)", action: .testCryptoTapped)
                        testButton("🔑 Test Key Recovery (local)", action: .testKeyRecoveryTapped)
                    } header: {
                        sectionHeader("Automated Tests")
                    }

                    Divider()

                    // Log output
                    Section {
                        ForEach(Array(store.log.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(line.hasPrefix("❌") ? .red : line.hasPrefix("✅") || line.hasPrefix("🎉") ? .green : DesignColors.text)
                        }

                        if store.log.isEmpty {
                            Text("Tap a test button above to see results")
                                .font(.raleway("Regular", size: 14, relativeTo: .body))
                                .foregroundStyle(DesignColors.textPlaceholder)
                        }
                    } header: {
                        sectionHeader("Log")
                    }
                }
                .padding(AppLayout.horizontalPadding)
            }
            .background(DesignColors.background)
            .navigationTitle("Bonds Test")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { store.send(.onAppear) }
        }
    }

    private func testButton(_ title: String, action: BondsTestFeature.Action) -> some View {
        Button {
            store.send(action)
        } label: {
            HStack {
                Text(title)
                    .font(.raleway("SemiBold", size: 15, relativeTo: .body))
                Spacer()
                if store.isRunning {
                    ProgressView()
                        .tint(DesignColors.accentWarm)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(DesignColors.text)
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.white)
            )
            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.raleway("Bold", size: 13, relativeTo: .caption))
            .foregroundStyle(DesignColors.textSecondary)
            .textCase(.uppercase)
    }
}
