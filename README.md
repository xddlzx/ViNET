# ViNET

ViNET is an offline, real-time object detection and depth estimation iOS app designed to empower visually impaired users with instant, multi-modal feedback. By combining lightweight CoreML models with a minimalist interface, ViNET delivers object type, position, and precise distance information—via speech and haptic cues—without ever requiring a network connection.

---

## Key Features

* **Real-Time Object Detection**

  * Detects 80 object categories (e.g., pedestrian, vehicle, obstacle) entirely on-device with YOLOv8s.
* **Accurate Depth Estimation**

  * Estimates meter-level distances using MiDaS\_Small and CoreML optimizations.
* **Multi-Modal Feedback**

  * **Speech**: “A table is 75.4 centimeters to the right.”
* **Offline & Privacy-First**

  * No internet needed; all video frames and model weights stay on the user’s device
* **Battery-Friendly**

  * Maintains \~30 FPS preview while keeping CPU usage below 70%

---

## Installation

1. Clone this repository:

   ```bash
   git clone https://github.com/your-org/vinet.git](https://github.com/xddlzx/ViNET.git
   ```
2. Open **ViNET.xcodeproj** in Xcode (14.0+).
3. Ensure you have an iPhone device (iOS 15.0+) connected or select a compatible simulator.
4. Build & run the app:

   * **Product → Run** (⌘R)

---

## Usage

1. Grant **Camera Access** when prompted.
2. Tap the **Start** button to begin live object detection.
3. Listen for spoken cues.

---

## Project Structure

```
ViNET/
├── Models/
│   ├── YOLOv8s.mlmodel
│   └── MiDaS_Small.mlmodel
├── Sources/
│   ├── CameraSession.swift
│   ├── ObjectDetector.swift
│   ├── DepthEstimator.swift
│   └── VoiceReporter.swift
├── Resources/
│   ├── LaunchScreen.storyboard
│   └── Assets.xcassets
└── ViNET.xcodeproj
```

---

## Contributing

1. Fork the repo and create a new branch for your feature/bugfix.
2. Implement your changes and write unit tests where applicable.
3. Open a Pull Request against **main** and describe your changes.

---

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
