// VoiceReporter.swift
import AVFoundation

class VoiceReporter: NSObject {
  private let synthesizer = AVSpeechSynthesizer()

  /// Holds the most recent sentence that should be spoken next
  private var pendingText: String?

  override init() {
    super.init()
    synthesizer.delegate = self
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback,
                                                      mode: .spokenAudio,
                                                      options: [])
      try AVAudioSession.sharedInstance().setActive(true,
                                                    options: .notifyOthersOnDeactivation)
    } catch { print("Audio session error:", error) }
  }

  // MARK: – Public API -------------------------------------------------------

  func speak(detections: [(Detection, Double)]) {
    guard !detections.isEmpty else { return }

    // Build one concise English sentence
    let sentence = detections.map { det, dist -> String in
      let side: String
      switch det.boundingBox.midX {
        case ..<0.33: side = "left"
        case 0.66...: side = "right"
        default:      side = "in front"
      }
      return String(format: "A %@ is %.1f centimetres to the %@.",
                    det.label, dist, side)
    }.joined(separator: " ")

    // If we're not speaking, speak immediately
    guard synthesizer.isSpeaking else {
      speakNow(sentence)
      return
    }

    // Otherwise update the pending slot (overwrite older pending text)
    pendingText = sentence
    // Do NOT stop current speech; we'll speak this when it finishes
  }

  // MARK: – Private helpers --------------------------------------------------

  private func speakNow(_ text: String) {
    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
    utterance.rate  = 0.45
    synthesizer.speak(utterance)
  }
}

// MARK: – Delegate -----------------------------------------------------------

extension VoiceReporter: AVSpeechSynthesizerDelegate {
  func speechSynthesizer(_ s: AVSpeechSynthesizer,
                         didFinish utterance: AVSpeechUtterance) {
    // When current utterance finishes, play the latest pending one (if any)
    if let next = pendingText {
      pendingText = nil
      speakNow(next)
    }
  }
}
