import AVFoundation
import SwiftUI
import UIKit

struct QrScannerView: UIViewControllerRepresentable {
    let onScanned: (String) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScanned: onScanned)
    }

    func makeUIViewController(context: Context) -> QrScannerViewController {
        let vc = QrScannerViewController()
        vc.metadataDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: QrScannerViewController, context: Context) {}

    static func dismantleUIViewController(_ uiViewController: QrScannerViewController, coordinator: Coordinator) {
        uiViewController.stopSession()
    }

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let onScanned: (String) -> Void
        private var done = false

        init(onScanned: @escaping (String) -> Void) {
            self.onScanned = onScanned
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            guard !done,
                  let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let val = obj.stringValue, !val.isEmpty else { return }
            done = true
            onScanned(val)
        }
    }
}

final class QrScannerViewController: UIViewController {
    weak var metadataDelegate: AVCaptureMetadataOutputObjectsDelegate?

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var fallbackStack: UIStackView?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        checkPermissionAndConfigure()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopSession()
    }

    deinit {
        stopSession()
    }

    func stopSession() {
        guard let session = captureSession else { return }
        if session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                session.stopRunning()
            }
        }
    }

    private func checkPermissionAndConfigure() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureCaptureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted {
                        self.configureCaptureSession()
                    } else {
                        self.showFallback(
                            title: t("未获得相机权限"),
                            message: t("请在系统「设置 → 锁匣」中允许访问相机以扫描二维码。"),
                            showSettingsButton: true
                        )
                    }
                }
            }
        case .denied, .restricted:
            showFallback(
                title: t("未获得相机权限"),
                message: t("请在系统「设置 → 锁匣」中允许访问相机以扫描二维码。"),
                showSettingsButton: true
            )
        @unknown default:
            showFallback(
                title: t("当前设备不支持相机扫描"),
                message: "",
                showSettingsButton: false
            )
        }
    }

    private func configureCaptureSession() {
        let session = AVCaptureSession()
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            showFallback(
                title: t("当前设备不支持相机扫描"),
                message: "",
                showSettingsButton: false
            )
            return
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.setMetadataObjectsDelegate(metadataDelegate, queue: .main)
            if output.availableMetadataObjectTypes.contains(.qr) {
                output.metadataObjectTypes = [.qr]
            }
        }

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.frame = view.bounds
        preview.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(preview, at: 0)

        self.captureSession = session
        self.previewLayer = preview

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    private func showFallback(title: String, message: String, showSettingsButton: Bool) {
        fallbackStack?.removeFromSuperview()

        let icon = UIImageView(image: UIImage(systemName: "camera.fill"))
        icon.tintColor = UIColor.white.withAlphaComponent(0.7)
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 40),
            icon.heightAnchor.constraint(equalToConstant: 40)
        ])

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [icon, titleLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        if !message.isEmpty {
            let msgLabel = UILabel()
            msgLabel.text = message
            msgLabel.textColor = UIColor.white.withAlphaComponent(0.75)
            msgLabel.font = .systemFont(ofSize: 13)
            msgLabel.textAlignment = .center
            msgLabel.numberOfLines = 0
            stack.addArrangedSubview(msgLabel)
        }

        if showSettingsButton {
            let btn = UIButton(type: .system)
            btn.setTitle(t("前往设置"), for: .normal)
            btn.setTitleColor(.white, for: .normal)
            btn.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
            btn.backgroundColor = UIColor(red: 79 / 255, green: 70 / 255, blue: 229 / 255, alpha: 1)
            btn.layer.cornerRadius = 12
            btn.contentEdgeInsets = UIEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
            btn.addTarget(self, action: #selector(openAppSettings), for: .touchUpInside)
            stack.addArrangedSubview(btn)
        }

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32)
        ])
        self.fallbackStack = stack
    }

    @objc private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
