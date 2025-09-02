//
//  ChatsView.swift
//  PeerShield
//
//  Created by Rishit Bafna on 9/1/25.
//


import SwiftUI

struct ChatsView: View {
    @EnvironmentObject var contactStore: ContactStore
    @EnvironmentObject var messageStore: MessageStore

    var body: some View {
        NavigationStack {
            List {
                ForEach(contactStore.contacts) { c in
                    NavigationLink {
                        ChatDetailView(contact: c)
                    } label: {
                        let last = messageStore.forContact(c.id).last
                        VStack(alignment: .leading, spacing: 2) {
                            Text(c.displayName).font(.headline)
                            Text(last == nil ? "No messages yet" : "Last message at \(last!.timestamp.formatted(date: .omitted, time: .standard))")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Chats")
        }
    }
}
