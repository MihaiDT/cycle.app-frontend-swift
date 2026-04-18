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

        public init() {}
    }

    public enum Action: Sendable {
        case testCryptoTapped
        case testKeyRecoveryTapped
        case initializeKeysTapped
        case fetchBondsTapped
        case createTestBondTapped
        case appendLog(String)
    }

    @Dependency(\.bondCrypto) var bondCrypto
    @Dependency(\.bondLocal) var bondLocal
    @Dependency(\.keychainClient) var keychain

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {

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

                    // Local tests (no server needed)
                    Section {
                        testButton("🔐 Test Crypto (local)", action: .testCryptoTapped)
                        testButton("🔑 Test Key Recovery (local)", action: .testKeyRecoveryTapped)
                    } header: {
                        sectionHeader("Local Tests (no server)")
                    }

                    Divider()

                    // Server tests
                    Section {
                        testButton("🔑 Initialize Keys", action: .initializeKeysTapped)
                        testButton("📡 Fetch My Bonds", action: .fetchBondsTapped)
                        testButton("➕ Create Test Bond", action: .createTestBondTapped)
                    } header: {
                        sectionHeader("Server Tests (needs backend)")
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
