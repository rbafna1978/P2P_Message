//
//  Message.swift
//  PeerShield
//
//  Created by Rishit Bafna on 9/1/25.
//


import Foundation

struct Message: Identifiable, Codable, Hashable {
    enum Direction: String, Codable { case incoming, outgoing }
    var id: UUID = .init()
    var contactID: UUID
    var timestamp: Date
    var direction: Direction
    var ciphertext: Data   // cipher | tag
    var nonce: Data
    var signature: Data
    var counter: UInt64    // used for HKDF rekey rotation derivation info
}
