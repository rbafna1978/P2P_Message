//
//  SecureStore.swift
//  PeerShield
//
//  Created by Rishit Bafna on 9/1/25.
//


import Foundation

/// Simple file-based store with complete protection; messages are saved as ciphertext-only.
enum SecureStore {
    enum Kind: String {
        case contacts = "contacts.json"
        case messages = "messages.json"
    }

    static func url(_ kind: Kind) throws -> URL {
        let dir = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return dir.appendingPathComponent(kind.rawValue)
    }

    static func load<T: Decodable>(_ type: T.Type, kind: Kind) -> T? {
        do {
            let u = try url(kind)
            let data = try Data(contentsOf: u)
            return try JSONDecoder().decode(T.self, from: data)
        } catch { return nil }
    }

    static func save<T: Encodable>(_ val: T, kind: Kind) {
        do {
            let data = try JSONEncoder().encode(val)
            let u = try url(kind)
            try data.write(to: u, options: [.atomic, .completeFileProtection])
        } catch {
            print("SecureStore save error:", error)
        }
    }
}
