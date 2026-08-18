# >_ ByteScanner //

![iOS 16.0+](https://img.shields.io/badge/iOS-16.0%2B-00FF66?style=flat-square)
![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-00E5FF?style=flat-square)
![CoreBluetooth](https://img.shields.io/badge/Framework-CoreBluetooth-C000FF?style=flat-square)

A high-performance, cyberpunk-themed Bluetooth Low Energy (BLE) scanner and signal-tracking utility built with SwiftUI for iOS. Designed for locating misplaced smart devices around the home, auditing GATT attributes, detecting BLE packet floods, and performing directional proximity "foxhunting."

---

## ⚡ Key Features

* **Sensor Hub Dashboard:** Dedicated grid interface isolating **Closest Scan**, **All Devices**, **Categories**, **AirTags**, and **Unknown Nodes**.
* **Imperial Proximity Engine:** Refined RSSI distance estimation using a 5-sample moving average and an indoor path-loss model ($n = 2.8$) mapped to intuitive range buckets (*1–3 ft*, *3–6 ft*, *6–12 ft*, *12–20 ft*).
* **Foxhunt Directional Tracker:** Continuous high-duty cycle scanning with dynamic audio beeps that scale in frequency as you get closer to target nodes.
* **ATT/GATT Inspector:** Connect directly to peripherals to enumerate advertised services, characteristics, and access permission flags (`READ`, `WRITE`, `NOTIFY`, `INDICATE`).
* **BLE Spam Anomaly Monitor:** Real-time packet velocity tracking (`P/S`) to detect and alert against high-density advertisement flood attacks.
* **Cyberpunk Visuals & FX:** Customizable matrix color palettes (*Green, Purple, Teal, Pink*), digital matrix rain graphics, flowing animated borders, and a global graphics FX toggle switch in settings.

---

## 🛠 Tech Stack

| Component | Technology |
| :--- | :--- |
| **Language** | Swift 5.9+ |
| **UI Framework** | SwiftUI |
| **Hardware Interface** | CoreBluetooth (`CBCentralManager`, `CBPeripheral`) |
| **Audio Engine** | AudioToolbox (`AudioServicesPlaySystemSound`) |
| **Persistence** | `@AppStorage` (Themes, Watchlists, FX Toggles) |

---

## 📋 Requirements

* **IDE:** Xcode 15.0+
* **Deployment Target:** iOS 16.0+
* **Hardware Requirement:** Physical iOS device required. CoreBluetooth central radio scanning is not supported in Xcode Simulators.

---

## 🚀 Installation & Setup

1. **Clone the repository:**
   ```bash
   git clone [https://github.com/g-hostproxy/ByteScanner.git](https://github.com/g-hostproxy/ByteScanner.git)
   cd ByteScanner
