// ViewController.swift
import UIKit

class ViewController: UIViewController {
  private let camera = CameraSession()
  private var detector: ObjectDetector!
  private var estimator: DepthEstimator!
  private let reporter = VoiceReporter()
  private var lastRun = Date.distantPast

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .black

    // insert preview layer
    view.layer.insertSublayer(camera.previewLayer, at: 0)

    // wire up camera delegate
    camera.delegate = self
    camera.start()

    // init models
    guard let det = ObjectDetector(),
          let est = DepthEstimator()
    else {
      fatalError("🔴 Model initialization failed")
    }
    detector = det
    estimator = est
  }

  // make sure preview fills the view once we have its final size
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    camera.previewLayer.frame = view.bounds
  }
}

extension ViewController: CameraSessionDelegate {
  func cameraSession(_ session: CameraSession,
                     didCapturePixelBuffer buffer: CVPixelBuffer) {
    let now = Date()
    guard now.timeIntervalSince(lastRun) >= 2 else { return }
    lastRun = now

    detector.detectObjects(in: buffer) { [weak self] dets in
      guard let self = self, !dets.isEmpty else { return }

      let tops = dets.sorted(by: { $0.confidence > $1.confidence })
                    .prefix(3)
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
