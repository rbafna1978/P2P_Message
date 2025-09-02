//
//  QRCodeView.swift
//  PeerShield
//
//  Created by Rishit Bafna on 9/1/25.
//


import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRCodeView: View {
    let text: String
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    var body: some View {
        if let img = generateQR(text) {
            Image(uiImage: img)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
        } else {
            Color.gray.opacity(0.1)
        }
    }

    private func generateQR(_ str: String) -> UIImage? {
        let data = Data(str.utf8)
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        if let cg = context.createCGImage(scaled, from: scaled.extent) {
            return UIImage(cgImage: cg)
        }
        return nil
    }
}
