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

extension BondLocalClient: DependencyKey {
    public static let liveValue = BondLocalClient(
        initializeKeys: { },
        getPublicKey: { Data() },
        createBond: { _ in BondInfo(id: "", partnerID: "", status: .pending, createdAt: Date()) },
        acceptBond: { _ in BondInfo(id: "", partnerID: "", status: .active, createdAt: Date()) },
        getMyBonds: { [] },
        revokeBond: { _ in },
        uploadSummary: { _, _ in },
        downloadPartnerSummary: { _ in nil },
        backupKey: { _ in },
        restoreKey: { _ in }
    )

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
