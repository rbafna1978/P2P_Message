//
//  PairView.swift
//  PeerShield
//
//  Created by Rishit Bafna on 9/1/25.
//


import SwiftUI

struct PairView: View {
    @EnvironmentObject var keyManager: KeyManager
    @EnvironmentObject var contactStore: ContactStore

    @State private var showScanner = false
    @State private var lastError: String?

    var myExport: String {
        Contact(
            displayName: keyManager.displayName,
            agreementPubKey: keyManager.agreementPublicData,
            signingPubKey: keyManager.signingPublicData
        ).exportPayload
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                GroupBox("My QR (share to pair)") {
                    QRCodeView(text: myExport)
                        .frame(width: 240, height: 240)
                        .padding(.vertical, 8)
                    Text("Share this QR with your peer. They scan it to add you as a trusted contact.")
                        .font(.footnote).foregroundStyle(.secondary)
                }

                Button {
                    showScanner = true
                } label: {
                    Label("Scan QR to Add Contact", systemImage: "qrcode.viewfinder")
                }
                .buttonStyle(.borderedProminent)

                if let err = lastError {
                    Text(err).foregroundStyle(.red).font(.footnote)
                }

                List {
                    Section("Paired Contacts") {
                        ForEach(contactStore.contacts) { c in
                            VStack(alignment: .leading) {
                                Text(c.displayName).font(.headline)
                                Text("Signing key: \(c.signingPubKey.base64EncodedString().prefix(16))…")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }.listStyle(.insetGrouped)

                Spacer()
            }
            .padding()
            .navigationTitle("Pair")
        }
        .sheet(isPresented: $showScanner) {
            ScannerView { result in
                switch result {
                case .success(let str):
                    do {
                        let contact = try Contact.fromExport(str)
                        contactStore.add(contact)
                        showScanner = false
                    } catch {
                        lastError = "Invalid QR: \(error.localizedDescription)"
                    }
                case .failure(let err):
                    lastError = err.localizedDescription
                }
            }
        }
    }
}
