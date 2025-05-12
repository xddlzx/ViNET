// ViewController.swift

import UIKit
import AVFoundation       // ← for playing MP3

class ViewController: UIViewController {
    // MARK: – AI / Camera
    private let camera = CameraSession()
    private var detector: ObjectDetector!
    private var estimator: DepthEstimator!
    private let reporter = VoiceReporter()
    private var lastRun = Date.distantPast

    // MARK: – Audio
    private var audioPlayer: AVAudioPlayer?
    private var warningPlayer: AVAudioPlayer?

    // MARK: – Pause State & Overlay
    private var isPaused = false
    private var pauseOverlay: UIView?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        // 1) Play opening sound
        playOpeningSound()

        // 2) Setup pause/resume gestures
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTap)

        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap(_:)))
        singleTap.numberOfTapsRequired = 1
        singleTap.require(toFail: doubleTap)
        view.addGestureRecognizer(singleTap)

        // 3) Insert preview layer
        view.layer.insertSublayer(camera.previewLayer, at: 0)

        // 4) Wire up camera delegate & start
        camera.delegate = self
        camera.start()

        // 5) Initialize AI models
        guard let det = ObjectDetector(),
              let est = DepthEstimator()
        else {
            fatalError("🔴 Model initialization failed")
        }
        detector = det
        estimator = est
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        camera.previewLayer.frame = view.bounds
        pauseOverlay?.frame = view.bounds
    }

    // MARK: – Gesture Handlers

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        guard !isPaused else { return }
        pauseCamera()
    }

    @objc private func handleSingleTap(_ gesture: UITapGestureRecognizer) {
        guard isPaused else { return }
        resumeCamera()
    }

    private func pauseCamera() {
        isPaused = true
        camera.stop()                // stop capture & preview
        showPauseOverlay()
        playWarningSound()
    }

    private func resumeCamera() {
        isPaused = false
        hidePauseOverlay()
        camera.start()
    }

    // MARK: – Pause Overlay

    private func showPauseOverlay() {
        if pauseOverlay == nil {
            let overlay = UIView(frame: view.bounds)
            overlay.backgroundColor = UIColor.black.withAlphaComponent(0.6)

            let label = UILabel()
            label.text = "Camera paused, please tap the screen to continue"
            label.textColor = .white
            label.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
            label.numberOfLines = 0
            label.textAlignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false

            overlay.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: overlay.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: overlay.centerYAnchor),
                label.leadingAnchor.constraint(greaterThanOrEqualTo: overlay.leadingAnchor, constant: 20),
                label.trailingAnchor.constraint(lessThanOrEqualTo: overlay.trailingAnchor, constant: -20)
            ])

            pauseOverlay = overlay
        }
        if let overlay = pauseOverlay {
            view.addSubview(overlay)
        }
    }

    private func hidePauseOverlay() {
        pauseOverlay?.removeFromSuperview()
    }

    // MARK: – Audio Helpers

    private func playOpeningSound() {
        guard let path = Bundle.main.path(forResource: "welcome", ofType: "mp3") else {
            print("[Audio] welcome.mp3 not found")
            return
        }
        let url = URL(fileURLWithPath: path)
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("[Audio] Failed to play welcome.mp3: \(error)")
        }
    }

    private func playWarningSound() {
        guard let path = Bundle.main.path(forResource: "warning", ofType: "mp3") else {
            print("[Audio] warning.mp3 not found")
            return
        }
        let url = URL(fileURLWithPath: path)
        do {
            warningPlayer = try AVAudioPlayer(contentsOf: url)
            warningPlayer?.prepareToPlay()
            warningPlayer?.play()
        } catch {
            print("[Audio] Failed to play warning.mp3: \(error)")
        }
    }
}

// MARK: – CameraSessionDelegate

extension ViewController: CameraSessionDelegate {
    func cameraSession(_ session: CameraSession,
                       didCapturePixelBuffer buffer: CVPixelBuffer) {
        // Skip processing while paused
        guard !isPaused else { return }

        let now = Date()
        guard now.timeIntervalSince(lastRun) >= 2 else { return }
        lastRun = now

        detector.detectObjects(in: buffer) { [weak self] dets in
            guard let self = self, !dets.isEmpty else { return }

            let tops = dets.sorted(by: { $0.confidence > $1.confidence }).prefix(3)
            var results: [(Detection, Double)] = []

            for d in tops {
                if let dist = self.estimator.estimateDistance(
                                from: buffer,
                                boundingBox: d.boundingBox) {
                    results.append((d, dist))
                }
            }
            guard !results.isEmpty else { return }

            DispatchQueue.main.async {
                self.reporter.speak(detections: results)
            }
        }
    }
}
