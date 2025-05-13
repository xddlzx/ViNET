import UIKit
import AVFoundation
import AudioToolbox    // ← for kSystemSoundID_Vibrate

class ViewController: UIViewController {
    // MARK: – AI / Camera
    private let camera = CameraSession()
    private var detector: ObjectDetector!
    private var estimator: DepthEstimator!
    private let reporter = VoiceReporter()
    private var lastRun = Date.distantPast

    // MARK: – Audio
    private var audioPlayer: AVAudioPlayer?      // Opening sound player

    // MARK: – UI
    private let instructionLabel: UILabel = {
        let label = UILabel()
        label.text = "Double-click the screen to stop, and single-click to continue."
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 1
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: – Pause State & Overlay
    private var isPaused = false
    private var pauseOverlay: UIView?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        // Add persistent instruction label
        view.addSubview(instructionLabel)
        NSLayoutConstraint.activate([
            instructionLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            instructionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            instructionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
        ])

        // Play the welcome tone
        playOpeningSound()

        // Setup double-tap to pause (with vibration)
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTap)

        // Setup single-tap to resume
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap(_:)))
        singleTap.numberOfTapsRequired = 1
        singleTap.require(toFail: doubleTap)
        view.addGestureRecognizer(singleTap)

        // Insert camera preview
        view.layer.insertSublayer(camera.previewLayer, at: 0)
        camera.delegate = self
        camera.start()

        // Initialize AI models
        guard let det = ObjectDetector(), let est = DepthEstimator() else {
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

        // Vibrate immediately on double-tap
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))

        // Then pause
        pauseCamera()
    }

    @objc private func handleSingleTap(_ gesture: UITapGestureRecognizer) {
        guard isPaused else { return }

        // Vibrate on resume
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        resumeCamera()
    }

    // MARK: – Pause / Resume

    private func pauseCamera() {
        isPaused = true
        camera.stop()                      // Halt capture
        showPauseOverlay()                 // Black screen + message
    }

    private func resumeCamera() {
        isPaused = false
        hidePauseOverlay()
        camera.start()
    }

    // MARK: – Overlay UI

    private func showPauseOverlay() {
        if pauseOverlay == nil {
            let overlay = UIView(frame: view.bounds)
            overlay.backgroundColor = .black

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
        guard let url = Bundle.main.url(forResource: "welcome", withExtension: "mp3") else {
            print("[Audio] welcome.mp3 not found in bundle.")
            return
        }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("[Audio] Failed to play welcome.mp3: \(error)")
        }
    }
}

// MARK: – CameraSessionDelegate

extension ViewController: CameraSessionDelegate {
    func cameraSession(_ session: CameraSession,
                       didCapturePixelBuffer buffer: CVPixelBuffer) {
        // Skip while paused
        guard !isPaused else { return }

        let now = Date()
        guard now.timeIntervalSince(lastRun) >= 2 else { return }
        lastRun = now

        detector.detectObjects(in: buffer) { [weak self] dets in
            guard let self = self, !dets.isEmpty else { return }
            let tops = dets.sorted(by: { $0.confidence > $1.confidence }).prefix(1)
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
