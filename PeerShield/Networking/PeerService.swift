//
//  PeerService.swift
//  PeerShield
//
//  Created by Rishit Bafna on 9/1/25.
//


import Foundation
import MultipeerConnectivity
import CryptoKit

final class PeerService: NSObject, ObservableObject {
    private var keyManager: KeyManager!
    private var contactStore: ContactStore!
    private var messageStore: MessageStore!

    private var myPeerID: MCPeerID!
    private let serviceType = "pshieldchat" // <= 15 chars, lowercase
    private var advertiser: MCNearbyServiceAdvertiser!
    private var browser: MCNearbyServiceBrowser!
    private var session: MCSession!

    // Handshake cache
    @Published var connectedContact: Contact?

    func bootstrapDependencies(keyManager: KeyManager, contactStore: ContactStore, messageStore: MessageStore) {
        self.keyManager = keyManager
        self.contactStore = contactStore
        self.messageStore = messageStore

        // Stable-ish name from signing key prefix
        let sigB64 = keyManager.signingPublicData.base64EncodedString()
        let display = "PS-" + String(sigB64.prefix(8))
        myPeerID = MCPeerID(displayName: display)

        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .none) // we do E2E ourselves
        session.delegate = self

        advertiser = MCNearbyServiceAdvertiser(
            peer: myPeerID,
            discoveryInfo: [
                "displayName": keyManager.displayName,
                "signingPubKey": keyManager.signingPublicData.base64EncodedString()
            ],
            serviceType: serviceType
        )
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()

        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
    }

    // MARK: - Identity frame

    struct IdentityFrame: Codable {
        let displayName: String
        let signingPubKey: Data
        let agreementPubKey: Data
        let signature: Data // over (displayName | signingPubKey | agreementPubKey)
    }

    private func makeIdentityFrame() throws -> Data {
        let payload = IdentityFrame(
            displayName: keyManager.displayName,
            signingPubKey: keyManager.signingPublicData,
            agreementPubKey: keyManager.agreementPublicData,
            signature: try keyManager.signingPrivate.signature(
                for: keyManager.signingPublicData + keyManager.agreementPublicData + Data(keyManager.displayName.utf8)
            )
        )
        return try JSONEncoder().encode(payload)
    }

    private func parseIdentityFrame(_ data: Data) throws -> IdentityFrame {
        let frame = try JSONDecoder().decode(IdentityFrame.self, from: data)
        let pub = try Curve25519.Signing.PublicKey(rawRepresentation: frame.signingPubKey)
        let msg = frame.signingPubKey + frame.agreementPubKey + Data(frame.displayName.utf8)
        guard pub.isValidSignature(frame.signature, for: msg) else {
            throw NSError(domain: "PeerShield", code: -20, userInfo: [NSLocalizedDescriptionKey: "Bad identity sig"])
        }
        return frame
    }

    // MARK: - Chat send

    private var sendCounter: UInt64 = 1

    func send(message: String, to contact: Contact) {
        guard let sess = session, !sess.connectedPeers.isEmpty else { return }
        do {
            let key = try CryptoBox.deriveSymmetricKey(
                myPriv: keyManager.agreementPrivate,
                peerAgreementPub: contact.agreementPubKey,
                counter: sendCounter
            )
            let env = try CryptoBox.encrypt(
                message: message,
                key: key,
                signingKey: keyManager.signingPrivate,
                counter: sendCounter
            )
            sendCounter &+= 1

            let frame: [String: Any] = [
                "type": "chat",
                "toSigning": contact.signingPubKey.base64EncodedString(),
                "fromSigning": keyManager.signingPublicData.base64EncodedString(),
                "ciphertext": env.ciphertext.base64EncodedString(),
                "nonce": env.nonce.base64EncodedString(),
                "signature": env.signature.base64EncodedString(),
                "counter": env.counter
            ]
            let data = try JSONSerialization.data(withJSONObject: frame, options: [])
            try session.send(data, toPeers: sess.connectedPeers, with: .reliable)

            // Persist ciphertext-only
            let msg = Message(
                contactID: contact.id,
                timestamp: Date(),
                direction: .outgoing,
                ciphertext: env.ciphertext,
                nonce: env.nonce,
                signature: env.signature,
                counter: env.counter
            )
            messageStore.add(msg)
        } catch {
            print("send error:", error)
        }
    }
}

// MARK: - Advertiser / Browser / Session delegates

extension PeerService: MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate, MCSessionDelegate {
    // Discover peers → invite/connect
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 20)
    }
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
    }
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("adv error:", error)
    }
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("browse error:", error)
    }

    // Session state
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        if state == .connected {
            // Send our identity frame
            if let data = try? makeIdentityFrame() {
                try? session.send(data, toPeers: [peerID], with: .reliable)
            }
        }
        if state == .notConnected {
            DispatchQueue.main.async { self.connectedContact = nil }
        }
    }

    // Receive data: identity frame or chat message
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // Try identity frame first
        if let idFrame = try? parseIdentityFrame(data) {
            // Map to a known contact; if unknown, add it automatically so both
            // devices retain each other after the first handshake.
            if let contact = contactStore.contact(forSigningKey: idFrame.signingPubKey) {
                DispatchQueue.main.async { self.connectedContact = contact }
            } else {
                let contact = Contact(
                    displayName: idFrame.displayName,
                    agreementPubKey: idFrame.agreementPubKey,
                    signingPubKey: idFrame.signingPubKey
                )
                DispatchQueue.main.async {
                    self.contactStore.add(contact)
                    self.connectedContact = contact
                }
            }
            return
        }

        // Otherwise, treat as chat frame
        guard
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let type = obj["type"] as? String, type == "chat",
            let fromB64 = obj["fromSigning"] as? String,
            let toB64 = obj["toSigning"] as? String,
            let cipherB64 = obj["ciphertext"] as? String,
            let nonceB64 = obj["nonce"] as? String,
            let sigB64 = obj["signature"] as? String,
            let counter = obj["counter"] as? UInt64,
            let cipher = Data(base64Encoded: cipherB64),
            let nonce = Data(base64Encoded: nonceB64),
            let signature = Data(base64Encoded: sigB64),
            let fromKey = Data(base64Encoded: fromB64),
            let toKey = Data(base64Encoded: toB64)
        else { return }

        // Verify it's for us and from someone we know
        guard toKey == keyManager.signingPublicData, let contact = contactStore.contact(forSigningKey: fromKey) else { return }

        do {
            let sym = try CryptoBox.deriveSymmetricKey(
                myPriv: keyManager.agreementPrivate,
                peerAgreementPub: contact.agreementPubKey,
                counter: counter
            )
            let env = CryptoBox.Envelope(ciphertext: cipher, nonce: nonce, signature: signature, counter: counter)
            let plaintext = try CryptoBox.decrypt(env, key: sym, peerSigningPub: contact.signingPubKey)

            // Persist ciphertext (plaintext shown transiently in UI)
            let msg = Message(
                contactID: contact.id,
                timestamp: Date(),
                direction: .incoming,
                ciphertext: cipher,
                nonce: nonce,
                signature: signature,
                counter: counter
            )
            DispatchQueue.main.async {
                self.messageStore.add(msg)
                if self.connectedContact == nil { self.connectedContact = contact }
                // Optionally post notification / haptics
                print("Decrypted:", plaintext)
            }
        } catch {
            print("decrypt error:", error)
        }
    }

    // Unused stream/resource
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}
