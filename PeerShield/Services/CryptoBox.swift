//
//  CryptoBox.swift
//  PeerShield
//
//  Created by Rishit Bafna on 9/1/25.
//


import Foundation
import CryptoKit

struct CryptoBox {
    struct Envelope: Codable {
        let ciphertext: Data
        let nonce: Data
        let signature: Data
        let counter: UInt64
    }

    static func deriveSymmetricKey(
        myPriv: Curve25519.KeyAgreement.PrivateKey,
        peerAgreementPub: Data,
        counter: UInt64
    ) throws -> SymmetricKey {
        let peerPub = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: peerAgreementPub)
        let secret = try myPriv.sharedSecretFromKeyAgreement(with: peerPub)
        // HKDF w/ context = counter (rekey per message/epoch)
        var info = withUnsafeBytes(of: counter.bigEndian, { Data($0) })
        info.append("PeerShield-HKDF-v1".data(using: .utf8)!)
        return secret.hkdfDerivedSymmetricKey(using: SHA256.self, salt: Data(), sharedInfo: info, outputByteCount: 32)
    }

    static func encrypt(
        message: String,
        key: SymmetricKey,
        signingKey: Curve25519.Signing.PrivateKey,
        counter: UInt64
    ) throws -> Envelope {
        let plaintext = Data(message.utf8)
        let sealed = try AES.GCM.seal(plaintext, using: key)
        let cipher = sealed.ciphertext + sealed.tag
        let nonceData = sealed.nonce.withUnsafeBytes { Data($0) }
        let toSign = cipher + nonceData + withUnsafeBytes(of: counter.bigEndian, { Data($0) })
        let sig = try signingKey.signature(for: toSign)
        return Envelope(ciphertext: cipher, nonce: nonceData, signature: sig, counter: counter)
    }

    static func decrypt(
        _ env: Envelope,
        key: SymmetricKey,
        peerSigningPub: Data
    ) throws -> String {
        let peerPub = try Curve25519.Signing.PublicKey(rawRepresentation: peerSigningPub)
        let toVerify = env.ciphertext + env.nonce + withUnsafeBytes(of: env.counter.bigEndian, { Data($0) })
        guard peerPub.isValidSignature(env.signature, for: toVerify) else {
            throw NSError(domain: "PeerShield", code: -10, userInfo: [NSLocalizedDescriptionKey: "Invalid signature"])
        }
        guard env.ciphertext.count >= 16 else { throw NSError(domain: "PeerShield", code: -11) }
        let tag = env.ciphertext.suffix(16)
        let cipher = env.ciphertext.dropLast(16)
        let nonce = try AES.GCM.Nonce(data: env.nonce)
        let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: cipher, tag: tag)
        let plaintext = try AES.GCM.open(sealedBox, using: key)
        return String(decoding: plaintext, as: UTF8.self)
    }
}
