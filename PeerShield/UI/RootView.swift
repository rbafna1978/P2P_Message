//
//  RootView.swift
//  PeerShield
//
//  Created by Rishit Bafna on 9/1/25.
//


import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            ChatsView()
                .tabItem { Label("Chats", systemImage: "bubble.left.and.bubble.right.fill") }
            PairView()
                .tabItem { Label("Pair", systemImage: "qrcode") }
        }
    }
}
