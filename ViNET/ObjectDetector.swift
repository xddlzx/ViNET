// ObjectDetector.swift
import CoreML
import Vision

struct Detection {
  let label: String
  let confidence: VNConfidence
  let boundingBox: CGRect
}

class ObjectDetector {
  private let visionModel: VNCoreMLModel

  init?() {
    // 1) Load the precompiled “ObjectDetection.mlmodelc” bundle
    guard let url = Bundle.main.url(
            forResource: "ObjectDetection",
            withExtension: "mlmodelc")
    else {
      print("🔴 ObjectDetection.mlmodelc not found")
      return nil
    }

    // 2) Create MLModel
    let coreMLModel: MLModel
    do {
      coreMLModel = try MLModel(contentsOf: url,
                                configuration: ModelConfigHelper.make())
    } catch {
      print("🔴 CoreML load error:", error)
      return nil
    }

    // 3) Wrap for Vision
    do {
      visionModel = try VNCoreMLModel(for: coreMLModel)
    } catch {
      print("🔴 Vision model error:", error)
      return nil
    }
  }

  func detectObjects(in buffer: CVPixelBuffer,
                     completion: @escaping ([Detection]) -> Void) {
    let request = VNCoreMLRequest(model: visionModel) { req, err in
      if let err = err {
        print("🔴 Vision request failed:", err)
        completion([])
        return
      }
      guard let obs = req.results as? [VNRecognizedObjectObservation] else {
        completion([])
        return
      }
      let dets = obs.map {
        Detection(
          label: $0.labels.first?.identifier ?? "Unknown",
          confidence: $0.labels.first?.confidence ?? 0,
          boundingBox: $0.boundingBox
        )
      }
      completion(dets)
    }
    request.imageCropAndScaleOption = .scaleFill

    let handler = VNImageRequestHandler(
      cvPixelBuffer: buffer,
      orientation: .up,
      options: [:]
    )
    DispatchQueue.global(qos: .userInitiated).async {
      do { try handler.perform([request]) }
      catch {
        print("🔴 performVisionRequest error:", error)
        completion([])
      }
    }
  }
}
