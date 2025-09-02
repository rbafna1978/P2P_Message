//
//  ContactStore.swift
//  PeerShield
//
//  Created by Rishit Bafna on 9/1/25.
//


import Foundation

final class ContactStore: ObservableObject {
    @Published private(set) var contacts: [Contact] = []

    init() {
        if let saved: [Contact] = SecureStore.load([Contact].self, kind: .contacts) {
            contacts = saved
        }
    }

    func add(_ c: Contact) {
        if !contacts.contains(where: { $0.signingPubKey == c.signingPubKey }) {
            contacts.append(c)
            persist()
        }
    }

    func persist() { SecureStore.save(contacts, kind: .contacts) }

    func contact(forSigningKey key: Data) -> Contact? {
        contacts.first(where: { $0.signingPubKey == key })
    }
}
