import Foundation

struct SyncUploadEntry: Codable {
    let entryDate: String

    // Encrypted fields (base64 ciphertext)
    let journalEntry: String?
    let gratitude: String?
    let win: String?
    let tension: String?
    let singleWordFeeling: String?
    let latitude: String?
    let longitude: String?
    let city: String?
    let state: String?
    let country: String?

    // Plaintext fields (non-identifying metrics)
    let feeling: Int
    let sleepQuality: Int
    let feelingColorHex: String
    let drinks: Int
    let stepCount: Int?
    let walkingDistanceMeters: Double?
    let sleepHours: Double?
    let sleepREMHours: Double?
    let sleepDeepHours: Double?
    let sleepCoreHours: Double?
    let sleepAwakeMinutes: Double?
    let sleepOnset: String?
    let sleepInterruptionCount: Int?
    let sleepScore: Int?
    let screenTimeSeconds: Double?
    let pickups: Int?

    let createdAt: String
    let updatedAt: String
}

struct SyncUploadPayload: Codable {
    let entries: [SyncUploadEntry]
}

struct SyncUploadResponse: Codable {
    let syncedAt: String
    let count: Int
}

struct SyncDownloadResponse: Codable {
    let entries: [SyncDownloadEntry]
    let cursor: String?
}

struct SyncDownloadEntry: Codable {
    let entryDate: String

    // Encrypted fields
    let journalEntry: String?
    let gratitude: String?
    let win: String?
    let tension: String?
    let singleWordFeeling: String?
    let latitude: String?
    let longitude: String?
    let city: String?
    let state: String?
    let country: String?

    // Plaintext fields
    let feeling: Int
    let sleepQuality: Int
    let feelingColorHex: String
    let drinks: Int
    let stepCount: Int?
    let walkingDistanceMeters: Double?
    let sleepHours: Double?
    let sleepREMHours: Double?
    let sleepDeepHours: Double?
    let sleepCoreHours: Double?
    let sleepAwakeMinutes: Double?
    let sleepOnset: String?
    let sleepInterruptionCount: Int?
    let sleepScore: Int?
    let screenTimeSeconds: Double?
    let pickups: Int?

    let createdAt: String
    let updatedAt: String
}
