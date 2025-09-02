import SwiftUI

@main
struct PeerShieldApp: App {
    @StateObject private var keyManager = KeyManager()
    @StateObject private var contactStore = ContactStore()
    @StateObject private var messageStore = MessageStore()
    @StateObject private var peerService = PeerService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(keyManager)
                .environmentObject(contactStore)
                .environmentObject(messageStore)
                .environmentObject(peerService)
                .onAppear {
                    peerService.bootstrapDependencies(
                        keyManager: keyManager,
                        contactStore: contactStore,
                        messageStore: messageStore
                    )
                }
        }
    }
}
