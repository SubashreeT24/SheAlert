<div align="center">

# 🛡️ SheAlert

<img src="she_alert_app/assets/icon/app_icon.png" alt="SheAlert App Icon" width="120"/>

### *Your Safety, Your Control*

A Women Safety Monitoring System — Voice-Triggered & Manual SOS with Live Evidence Capture

![Arduino](https://img.shields.io/badge/Arduino-00979D?style=for-the-badge&logo=arduino&logoColor=white)
![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![NodeJS](https://img.shields.io/badge/Node.js-339933?style=for-the-badge&logo=nodedotjs&logoColor=white)
![ESP32](https://img.shields.io/badge/ESP32--S3-E7352C?style=for-the-badge&logo=espressif&logoColor=white)
![WhatsApp](https://img.shields.io/badge/WhatsApp_Alerts-25D366?style=for-the-badge&logo=whatsapp&logoColor=white)

</div>

---

## 📖 1. Overview

**SheAlert** is a real-time women's safety monitoring system that pairs an ESP32-S3 hardware device with a Flutter mobile app to send emergency alerts through two modes:

- 🎙️ **Automatic Mode** — Periodically listens for a secret trigger word (**"blueberry"**). Once detected, it captures a photo, records audio evidence, and instantly notifies emergency contacts over WhatsApp with **location, timestamp, and evidence** (image + `.wav` audio).
- 🆘 **Manual Mode** — A press-and-hold SOS button in the companion app for situations where speed matters more than evidence, sending live location and timestamp.

The system is built around one principle: **automatic mode maximizes evidence, manual mode maximizes speed.**

---

## ✨ 2. Features

- 🎙️ Automatic wake-word monitoring using repeated 5-second audio captures
- 📸 Automatic photo + audio evidence capture on trigger, sent via WhatsApp with location & timestamp
- 🆘 Press-and-hold **Manual SOS** (2 seconds) for rapid location-based alerts
- 💓 Heartbeat-based device connectivity status (device online/offline)
- 📇 Priority-ordered emergency contacts (up to 5, reorderable, swipe-to-delete)
- 📊 Alert history with Manual / Automatic / All filters + weekly stats

---

## 🛠️ 3. Tech Stack

| Layer | Technology | Purpose |
|---|---|---|
| **Hardware** | XIAO ESP32-S3 Sense (built-in mic + camera) | Captures audio & photo on trigger |
| **Firmware** | C++ / Arduino (ESP32-S3) | Records audio, controls camera, sends heartbeat over Wi-Fi |
| **Backend** | Node.js — Firebase Cloud Functions | Processes audio, manages alerts, uploads media |
| **Speech-to-Text** | ElevenLabs STT API | Converts recorded audio to text for trigger detection |
| **Database** | Firebase Firestore | Stores alerts (automatic/manual) & contacts |
| **File Storage** | Firebase Storage | Stores captured images & `.wav` audio files |
| **Notifications** | CircuitDigest Cloud API | Sends WhatsApp alerts to emergency contacts |
| **Mobile App** | Flutter (Dart) | Home, History, and Contacts management UI |
| **Realtime Sync** | Firebase Firestore listeners | Live device status & alert history updates |

---

## 🧩 4. System Architecture

### 4.1 Component Architecture

<p align="center">
  <img
    src="docs/component-architecture.svg"
    alt="SheAlert Component Architecture"
    width="900"
  />
</p>

### 4.2 Alert Flow — Automatic vs Manual

<p align="center">
  <img
    src="docs/alert-flow.svg"
    alt="SheAlert Automatic and Manual Alert Flow"
    width="900"
  />
</p>

> **Why two modes?** Automatic mode takes longer since it waits on audio recording, transcription, and photo upload — but produces stronger evidence. Manual mode skips these steps for faster delivery when every second counts. If no trigger word is found in a 5-second clip, the device waits 3 seconds before starting the next recording cycle.

---

## 🔩 5. Core Modules

### 5.1 Hardware — XIAO ESP32-S3 Sense

| Component | Detail |
|---|---|
| Microcontroller | ESP32-S3 (XIAO Sense variant) |
| Microphone | Built-in PDM mic |
| Camera | Built-in camera module |
| Power | USB power supply |
| Connectivity | Wi-Fi (HTTP client to Firebase Cloud Functions) |
| Heartbeat Interval | Every 30 seconds |

### 5.2 Backend — Firebase Cloud Functions

| Function | Responsibility |
|---|---|
| `processAudio` | Receives `.wav` audio, sends to ElevenLabs STT, checks for trigger word, creates alert, stores audio in Storage, sends audio via CircuitDigest |
| `uploadPhoto` | Receives JPEG photo, stores in Firebase Storage, links to alert, triggers WhatsApp image send via CircuitDigest |
| `heartbeat` | Updates device "last seen" timestamp in Firestore for online/offline status |

### 5.3 Mobile App — Flutter

| Screen | Functionality |
|---|---|
| **Home** | Connection status (device + internet), live GPS location, contact count, manual SOS button |
| **History** | Alert log filtered by Manual / Automatic / All, with total alerts & this-week stats |
| **Contacts** | Add, reorder (priority 1–5), and remove (swipe-to-delete with confirmation) emergency contacts |

---

## 🎯 6. Key Learnings

- **Audio capture on ESP32-S3** — coordinating repeated microphone recordings with camera capture and Wi-Fi communication on the same device
- **Designing for a trade-off, not just a feature** — automatic vs. manual mode forced explicit decisions about evidence vs. speed in an emergency UX
- **Wiring third-party APIs into one pipeline** — chaining ElevenLabs STT → Firestore → Storage → CircuitDigest Cloud into a single reliable alert flow
- **Realtime state across three layers** — keeping hardware, backend, and the Flutter app in sync via Firestore listeners

---

## 🚀 7. Future Improvements

- 🔐 Add user authentication (currently single-user, no login)
- 🔋 Battery-optimized / low-power listening mode for the ESP32-S3
- 🗣️ On-device wake-word detection to reduce cloud STT calls
- 🌐 Offline SMS fallback when there's no internet connectivity
- 🧭 Geofencing-based automatic alerts (e.g., unsafe zone detection)
- 📈 Analytics dashboard for alert trends over time

---

## 🙋 Author

Thirumalai Subashree — [GitHub](https://github.com/SubashreeT24)