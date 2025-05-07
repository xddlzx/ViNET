// ModelConfigHelper.swift
import CoreML

/// Provides a baseline configuration for all models in the app.
enum ModelConfigHelper {
  static func make() -> MLModelConfiguration {
    let cfg = MLModelConfiguration()
    // Optional: control CPU/GPU usage; adjust as needed
    cfg.computeUnits = .all
    return cfg
  }
}
