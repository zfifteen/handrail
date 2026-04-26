import AVFoundation
import SwiftUI
import UIKit

struct QRScannerView: View {
    @Environment(\.dismiss) private var dismiss
    let onPair: (PairingPayload) -> Void
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                QRScannerRepresentable { result in
                    switch result {
                    case .success(let payload):
                        onPair(payload)
                    case .failure(let error):
                        errorText = error.localizedDescription
                    }
                }
                .ignoresSafeArea()

                VStack(spacing: 10) {
                    Text(errorText ?? "Scan the QR code printed by handrail pair.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
                .padding()
            }
            .navigationTitle("Pair Handrail")
            .toolbar {
                Button("Close") { dismiss() }
            }
        }
    }
}

struct QRScannerRepresentable: UIViewControllerRepresentable {
    let onResult: (Result<PairingPayload, Error>) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.onResult = onResult
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}

final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onResult: ((Result<PairingPayload, Error>) -> Void)?
    private let session = AVCaptureSession()
    private var didReadCode = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configure()
    }

    private func configure() {
        guard let device = AVCaptureDevice.default(for: .video) else {
            onResult?(.failure(ScannerError.noCamera))
            return
        }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            let output = AVCaptureMetadataOutput()
            guard session.canAddInput(input), session.canAddOutput(output) else {
                onResult?(.failure(ScannerError.invalidCaptureSession))
                return
            }
            session.addInput(input)
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]

            let preview = AVCaptureVideoPreviewLayer(session: session)
            preview.videoGravity = .resizeAspectFill
            preview.frame = view.bounds
            view.layer.addSublayer(preview)

            DispatchQueue.global(qos: .userInitiated).async {
                self.session.startRunning()
            }
        } catch {
            onResult?(.failure(error))
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.layer.sublayers?.first?.frame = view.bounds
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !didReadCode,
              let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let text = object.stringValue else { return }
        do {
            let payload = try JSONDecoder().decode(PairingPayload.self, from: Data(text.utf8))
            didReadCode = true
            session.stopRunning()
            onResult?(.success(payload))
        } catch {
            onResult?(.failure(error))
        }
    }
}

enum ScannerError: LocalizedError {
    case noCamera
    case invalidCaptureSession

    var errorDescription: String? {
        switch self {
        case .noCamera: "No camera is available."
        case .invalidCaptureSession: "The camera could not scan QR codes."
        }
    }
}
