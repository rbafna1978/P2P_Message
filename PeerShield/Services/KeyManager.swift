//
//  KeyManager.swift
//  PeerShield
//
//  Created by Rishit Bafna on 9/1/25.
//


import Foundation
import UIKit
import CryptoKit

final class KeyManager: ObservableObject {
    private let agreementPrivKeyTag = "ps.agreement.priv"
    private let signingPrivKeyTag = "ps.signing.priv"

    @Published var displayName: String = UIDevice.current.name
    private(set) var agreementPrivate: Curve25519.KeyAgreement.PrivateKey!
    private(set) var signingPrivate: Curve25519.Signing.PrivateKey!

    var agreementPublicData: Data { agreementPrivate.publicKey.rawRepresentation }
    var signingPublicData: Data { signingPrivate.publicKey.rawRepresentation }

    init() {
        bootstrap()
    }

    private func bootstrap() {
        if
            let data = Keychain.load(account: agreementPrivKeyTag),
            let priv = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: data)
        {
            self.agreementPrivate = priv
        } else {
            let priv = Curve25519.KeyAgreement.PrivateKey()
            _ = Keychain.save(priv.rawRepresentation, account: agreementPrivKeyTag)
            self.agreementPrivate = priv
        }

        if
            let data = Keychain.load(account: signingPrivKeyTag),
            let priv = try? Curve25519.Signing.PrivateKey(rawRepresentation: data)
        {
            self.signingPrivate = priv
        } else {
            let priv = Curve25519.Signing.PrivateKey()
            _ = Keychain.save(priv.rawRepresentation, account: signingPrivKeyTag)
            self.signingPrivate = priv
        }
    }
}
