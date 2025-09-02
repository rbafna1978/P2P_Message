//
//  ChatDetailView.swift
//  PeerShield
//
//  Created by Rishit Bafna on 9/1/25.
//


import SwiftUI
import CryptoKit

struct ChatDetailView: View {
    @EnvironmentObject var keyManager: KeyManager
    @EnvironmentObject var messageStore: MessageStore
    @EnvironmentObject var peerService: PeerService

    let contact: Contact
    @State private var draft: String = ""

    var body: some View {
        VStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(messageStore.forContact(contact.id)) { m in
                            Bubble(message: m, contact: contact, keyManager: keyManager)
                        }
                    }.padding()
                }
                // Automatically keep the latest message in view
                .onChange(of: messageStore.forContact(contact.id).count) { _ in
                    if let last = messageStore.forContact(contact.id).last?.id {
                        withAnimation { proxy.scrollTo(last, anchor: .bottom) }
                    }
                }
            }

            HStack {
                TextField("Type a secure message", text: $draft)
                    .textFieldStyle(.roundedBorder)
                Button(action: {
                    let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    peerService.send(message: trimmed, to: contact)
                    draft = ""
                }) {
                    Image(systemName: "paperplane.fill")
                        .padding(.horizontal, 4)
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .navigationTitle(contact.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct Bubble: View {
    let message: Message
    let contact: Contact
    let keyManager: KeyManager

    var isOutgoing: Bool { message.direction == .outgoing }

    var body: some View {
        VStack(alignment: isOutgoing ? .trailing : .leading, spacing: 4) {
            Text(plaintextPreview)
                .padding(10)
                .background(isOutgoing ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: isOutgoing ? .trailing : .leading)
    }

    private var plaintextPreview: String {
        // Decrypt transiently for display
        do {
            let sym = try CryptoBox.deriveSymmetricKey(
                myPriv: keyManager.agreementPrivate,
                peerAgreementPub: (isOutgoing ? contact.agreementPubKey : contact.agreementPubKey),
                counter: message.counter
            )
            let env = CryptoBox.Envelope(ciphertext: message.ciphertext, nonce: message.nonce, signature: message.signature, counter: message.counter)
            return try CryptoBox.decrypt(env, key: sym, peerSigningPub: contact.signingPubKey)
        } catch {
            return "🔒 Unable to decrypt"
        }
    }
}
