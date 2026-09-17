//
//  QRScannerView.swift
//  DropIn
//
//  Live camera view that reads a friend's DropIn QR code, using Apple's
//  VisionKit scanner. Only real iPhones have a camera, so the Friends
//  screen checks `QRScanner.availability` first.
//

import SwiftUI
import Vision        // defines the `.qr` barcode type
import VisionKit     // the live camera scanner
import AVFoundation  // camera permission

enum QRScanner {
    enum Availability {
        case ready
        case needsPermission
        case denied
        case unsupported
    }

    static var availability: Availability {
        guard DataScannerViewController.isSupported else { return .unsupported }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .ready
        case .notDetermined: return .needsPermission
        default: return .denied
        }
    }

    /// Shows the system camera permission prompt. Returns true if allowed.
    static func requestPermission() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }
}

struct QRScannerView: UIViewControllerRepresentable {
    /// Called once with the first QR code's text.
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        if !scanner.isScanning {
            try? scanner.startScanning()
        }
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onScan: (String) -> Void
        private var didScan = false

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !didScan else { return }
            for item in addedItems {
                if case .barcode(let barcode) = item, let text = barcode.payloadStringValue {
                    didScan = true
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onScan(text)
                    return
                }
            }
        }
    }
}
