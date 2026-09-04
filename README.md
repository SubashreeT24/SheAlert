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

- 🎙️ **Automatic Mode** — Continuously listens for a secret trigger word (**"blueberry"**). Once detected, it captures a photo, records audio evidence, and instantly notifies emergency contacts over WhatsApp with **location, timestamp, and evidence** (image + `.wav` audio).
- 🆘 **Manual Mode** — A press-and-hold SOS button in the companion app for situations where speed matters more than evidence, sending just live location and timestamp.

The system is built around one principle: **automatic mode maximizes evidence, manual mode maximizes speed.**

---

## ✨ 2. Features

- 🎙️ Continuous audio monitoring with wake-word detection (trigger word: `blueberry`)
- 📸 Automatic photo + audio evidence capture on trigger, sent via WhatsApp with location & timestamp
- 🆘 One-touch **Manual SOS** (2-second press) for fast, evidence-free alerts
- 💓 Heartbeat-based device connectivity status (device online/offline)
- 📇 Priority-ordered emergency contacts (up to 5, reorderable, swipe-to-delete)
- 📊 Alert history with Manual / Automatic / All filters + weekly stats

---

## 🛠️ 3. Tech Stack

| Layer | Technology | Purpose |
|---|---|---|
| **Hardware** | XIAO ESP32-S3 Sense (built-in mic + camera) | Captures audio continuously & photo on trigger |
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

```mermaid
flowchart TD
    subgraph AUTO["Automatic Alert — trigger word 'blueberry'"]
        direction TB
        A1["ESP32-S3<br/>Records audio + photo"]
        A2["processAudio()<br/>Transcribe & check trigger"]
        A3["uploadPhoto()<br/>Store evidence & notify"]
        A1 --> A2 --> A3
    end

    subgraph MANUAL["Manual Alert — SOS held 2s"]
        direction TB
        M1["Flutter App<br/>Hold SOS button"]
        M2["Get GPS Location<br/>Live location fix"]
        M1 --> M2
    end

    subgraph SHARED["Shared Backend — Firebase + CircuitDigest Cloud API"]
        direction LR
        F[("Firestore<br/>Alerts + Contacts")]
        S[("Storage<br/>Images + Audio")]
        C["CircuitDigest Cloud<br/>WhatsApp Notification"]
    end

    A3 -->|"alert + evidence"| SHARED
    M2 -->|"alert + location"| SHARED

    classDef auto fill:#0f5132,stroke:#0a3d26,color:#fff
    classDef manual fill:#7a1f1f,stroke:#5c1717,color:#fff
    classDef shared fill:#0d3b66,stroke:#092a49,color:#fff
    class A1,A2,A3 auto
    class M1,M2 manual
    class F,S,C shared
