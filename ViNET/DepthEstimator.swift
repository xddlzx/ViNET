// DepthEstimator.swift  – FastDepth variant (224 × 224 RGB image input)
import CoreML
import CoreImage
import Accelerate

class DepthEstimator {
  private let model: MLModel
  private let ciContext = CIContext()
  private let outputKey: String            // e.g. "var_1438"
  private let target = 224                 // FastDepth expects 224×224

  init?() {
    // Model file is still called DepthEstimation.mlmodelc
    guard let url = Bundle.main.url(
            forResource: "DepthEstimation",
            withExtension: "mlmodelc") else {
      print("🔴 DepthEstimation.mlmodelc not found")
      return nil
    }
    do {
      model = try MLModel(contentsOf: url,
                          configuration: ModelConfigHelper.make())
    } catch {
      print("🔴 Depth model load error:", error)
      return nil
    }

    guard let k = model.modelDescription.outputDescriptionsByName.keys.first
    else { return nil }
    outputKey = k
    print("DepthEstimator: using output key '\(outputKey)'")
  }

  // MARK: – Crop + scale to target size
  private func makeInputBuffer(from src: CVPixelBuffer,
                               bbox: CGRect) -> CVPixelBuffer? {
    let W = CGFloat(CVPixelBufferGetWidth(src))
    let H = CGFloat(CVPixelBufferGetHeight(src))

    let rect = CGRect(
      x: bbox.minX * W,
      y: (1 - bbox.maxY) * H,
      width:  bbox.width  * W,
      height: bbox.height * H
    ).intersection(CGRect(x: 0, y: 0, width: W, height: H))

    guard !rect.isEmpty else { return nil }

    let ciImg = CIImage(cvPixelBuffer: src)
      .cropped(to: rect)
      .transformed(by: CGAffineTransform(scaleX: CGFloat(target) / rect.width,
                                         y: CGFloat(target) / rect.height))

    var dst: CVPixelBuffer?
    let ok = CVPixelBufferCreate(
      kCFAllocatorDefault,
      target, target,
      kCVPixelFormatType_32BGRA,
      [kCVPixelBufferCGImageCompatibilityKey: true,
       kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary,
      &dst)
    guard ok == kCVReturnSuccess, let buf = dst else { return nil }
    ciContext.render(ciImg, to: buf)
    return buf
  }

  // MARK: – Distance estimation
  func estimateDistance(from cameraBuf: CVPixelBuffer,
                        boundingBox: CGRect) -> Double? {

    guard let inBuf = makeInputBuffer(from: cameraBuf, bbox: boundingBox)
    else { return nil }

    let inKey  = model.modelDescription.inputDescriptionsByName.keys.first!
    let feats  = try? MLDictionaryFeatureProvider(
                   dictionary: [inKey: MLFeatureValue(pixelBuffer: inBuf)])
    guard let result = try? model.prediction(from: feats!),
          let invMap  = result.featureValue(for: outputKey)?.multiArrayValue
    else { return nil }

    // Handle any tensor rank (H×W, 1×H×W, or 1×C×H×W)
    let shp = invMap.shape.map { $0.intValue }
    let H = shp[shp.count - 2]
    let W = shp[shp.count - 1]
    let strideH = invMap.strides[shp.count - 2].intValue
    let strideW = invMap.strides[shp.count - 1].intValue
    let ptr = invMap.dataPointer.assumingMemoryBound(to: Float32.self)

    // Average inverse‑depth over central 50 % patch
    let y0 = H / 4, y1 = 3 * H / 4
    let x0 = W / 4, x1 = 3 * W / 4
    var sum: Float = 0
    for y in y0..<y1 {
      let row = ptr.advanced(by: y * strideH + x0 * strideW)
      vDSP_sve(row,
               vDSP_Stride(strideW),
               &sum,
               vDSP_Length(x1 - x0))
    }
    let meanInv = sum / Float((y1 - y0) * (x1 - x0))

    // Simple calibration (tweak 1.0–1.5 to taste)
    let metres = 0.02 / Double(meanInv)
    return metres
  }
}
