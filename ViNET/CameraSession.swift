// CameraSession.swift
import AVFoundation

protocol CameraSessionDelegate: AnyObject {
  func cameraSession(_ session: CameraSession, didCapturePixelBuffer pixelBuffer: CVPixelBuffer)
}

class CameraSession: NSObject {
  private let captureSession = AVCaptureSession()
  private let sessionQueue = DispatchQueue(label: "camera.session.queue")
  weak var delegate: CameraSessionDelegate?

  /// Public preview layer you can insert into any view’s layer
  public private(set) lazy var previewLayer: AVCaptureVideoPreviewLayer = {
    let layer = AVCaptureVideoPreviewLayer(session: self.captureSession)
    layer.videoGravity = .resizeAspectFill
    layer.connection?.videoOrientation = .portrait
    return layer
  }()

  override init() {
    super.init()
    configureSession()
  }

  private func configureSession() {
    captureSession.beginConfiguration()
    captureSession.sessionPreset = .high

    // Input
    guard
      let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                           for: .video,
                                           position: .back),
      let input = try? AVCaptureDeviceInput(device: device),
      captureSession.canAddInput(input)
    else {
      print("Camera input error")
      captureSession.commitConfiguration()
      return
    }
    captureSession.addInput(input)

    // Output
    let output = AVCaptureVideoDataOutput()
    output.alwaysDiscardsLateVideoFrames = true
    output.setSampleBufferDelegate(self, queue: sessionQueue)
    guard captureSession.canAddOutput(output) else {
      print("Camera output error")
      captureSession.commitConfiguration()
      return
    }
    captureSession.addOutput(output)
    if let conn = output.connection(with: .video) {
      conn.videoOrientation = .portrait
    }

    captureSession.commitConfiguration()
  }

  func start() {
    sessionQueue.async {
      if !self.captureSession.isRunning {
        self.captureSession.startRunning()
      }
    }
  }

  func stop() {
    sessionQueue.async {
      if self.captureSession.isRunning {
        self.captureSession.stopRunning()
      }
    }
  }
}

extension CameraSession: AVCaptureVideoDataOutputSampleBufferDelegate {
  func captureOutput(_ output: AVCaptureOutput,
                     didOutput sampleBuffer: CMSampleBuffer,
                     from connection: AVCaptureConnection) {
    guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
    delegate?.cameraSession(self, didCapturePixelBuffer: buffer)
  }
}
