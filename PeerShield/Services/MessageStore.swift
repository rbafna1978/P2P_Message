//
//  MessageStore.swift
//  PeerShield
//
//  Created by Rishit Bafna on 9/1/25.
//


import Foundation

final class MessageStore: ObservableObject {
    @Published private(set) var messages: [UUID: [Message]] = [:] // contactID -> messages

    init() {
        if let saved: [UUID: [Message]] = SecureStore.load([UUID: [Message]].self, kind: .messages) {
            messages = saved
        }
    }

    func add(_ m: Message) {
        var arr = messages[m.contactID] ?? []
        arr.append(m)
        messages[m.contactID] = arr.sorted(by: { $0.timestamp < $1.timestamp })
        persist()
    }

    func forContact(_ id: UUID) -> [Message] { messages[id] ?? [] }

    func persist() { SecureStore.save(messages, kind: .messages) }
}
