//
//  Contact.swift
//  PeerShield
//
//  Created by Rishit Bafna on 9/1/25.
//


import Foundation
import CryptoKit

struct Contact: Identifiable, Codable, Hashable {
    var id: UUID = .init()
    var displayName: String
    var agreementPubKey: Data // Curve25519.KeyAgreement.PublicKey raw
    var signingPubKey: Data   // Curve25519.Signing.PublicKey raw

    var exportPayload: String {
        let dict: [String: String] = [
            "displayName": displayName,
            "agreementPubKey": agreementPubKey.base64EncodedString(),
            "signingPubKey": signingPubKey.base64EncodedString()
        ]
        let data = try! JSONSerialization.data(withJSONObject: dict, options: [])
        return data.base64EncodedString()
    }

    static func fromExport(_ base64: String) throws -> Contact {
        guard let data = Data(base64Encoded: base64) else {
            throw NSError(domain: "PeerShield", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid QR"])
        }
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: String]
        guard
            let name = obj["displayName"],
            let ap = obj["agreementPubKey"], let apd = Data(base64Encoded: ap),
            let sp = obj["signingPubKey"], let spd = Data(base64Encoded: sp)
        else { throw NSError(domain: "PeerShield", code: -2, userInfo: [NSLocalizedDescriptionKey: "Bad fields"]) }
        return Contact(displayName: name, agreementPubKey: apd, signingPubKey: spd)
    }
}
