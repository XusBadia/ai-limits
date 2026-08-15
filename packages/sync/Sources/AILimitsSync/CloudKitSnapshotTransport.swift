#if canImport(CloudKit)
import AILimitsCore
import CloudKit
import Foundation

public actor CloudKitSnapshotTransport {
    public static let zoneName = "AILimitsPrivateV1"
    public static let recordName = "current-snapshot"

    private let database: CKDatabase
    private let zoneID = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(containerIdentifier: String) {
        self.database = CKContainer(identifier: containerIdentifier).privateCloudDatabase
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func prepare() async throws {
        do {
            _ = try await database.save(CKRecordZone(zoneID: zoneID))
        } catch let error as CKError where error.code == .zoneNotFound || error.code == .serverRejectedRequest {
            throw error
        } catch let error as CKError where error.code == .partialFailure {
            throw error
        } catch {
            // Existing zones may surface as an idempotent server response on some accounts.
        }
    }

    public func upload(_ envelope: SnapshotEnvelope) async throws {
        let valid = try envelope.validated()
        let id = CKRecord.ID(recordName: Self.recordName, zoneID: zoneID)
        let record: CKRecord
        do {
            record = try await database.record(for: id)
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: "UsageSnapshot", recordID: id)
        }
        record["schemaVersion"] = valid.schemaVersion as CKRecordValue
        record["generatedAt"] = valid.generatedAt as CKRecordValue
        record.encryptedValues["payload"] = try encoder.encode(valid) as CKRecordValue
        _ = try await database.save(record)
    }

    public func download() async throws -> SnapshotEnvelope? {
        let id = CKRecord.ID(recordName: Self.recordName, zoneID: zoneID)
        do {
            let record = try await database.record(for: id)
            guard let data = record.encryptedValues["payload"] as? Data else { throw SnapshotStoreError.invalidData }
            return try decoder.decode(SnapshotEnvelope.self, from: data).validated()
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    public func delete() async throws {
        let id = CKRecord.ID(recordName: Self.recordName, zoneID: zoneID)
        do { _ = try await database.deleteRecord(withID: id) }
        catch let error as CKError where error.code == .unknownItem { return }
    }
}
#endif

