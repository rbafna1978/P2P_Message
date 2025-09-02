//
//  ScannerView.swift
//  PeerShield
//
//  Created by Rishit Bafna on 9/1/25.
//


import SwiftUI
import AVFoundation

struct ScannerView: UIViewControllerRepresentable {
    enum ScanError: Error { case bad }
    var completion: (Result<String, Error>) -> Void

    func makeUIViewController(context: Context) -> ScannerVC {
        let vc = ScannerVC()
        vc.onResult = completion
        return vc
    }
    func updateUIViewController(_ uiViewController: ScannerVC, context: Context) {}
}

final class ScannerVC: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onResult: ((Result<String, Error>) -> Void)?

    private let session = AVCaptureSession()
    private let preview = AVCaptureVideoPreviewLayer()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            onResult?(.failure(ScannerView.ScanError.bad)); return
        }
        let output = AVCaptureMetadataOutput()
        guard session.canAddInput(input), session.canAddOutput(output) else {
            onResult?(.failure(ScannerView.ScanError.bad)); return
        }
        session.addInput(input)
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]

        preview.session = session
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)

        session.startRunning()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        preview.frame = view.bounds
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              obj.type == .qr, let str = obj.stringValue else { return }
        session.stopRunning()
        onResult?(.success(str))
        dismiss(animated: true)
    }
}
