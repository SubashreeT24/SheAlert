<div align="center">

# 🛡️ SheAlert

### A Women Safety Monitoring System — Voice-Triggered & Manual SOS with Live Evidence Capture

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

**SheAlert** is a real-time women's safety monitoring system that combines a wearable/embedded hardware device with a mobile app to send emergency alerts through two modes:

- 🎙️ **Automatic Mode** — Continuously listens for a secret trigger word ("**blueberry**"). Once detected, it captures a photo, records audio evidence, and instantly notifies emergency contacts over WhatsApp with **location, timestamp, and evidence (image URL and audio `.wav` file)**.
- 🆘 **Manual Mode** — A press-and-hold SOS button in the companion Flutter app for situations where speed matters more than evidence, sending just live location and timestamp — it does not depend on the ESP32-S3 device at all, only on the phone's internet and GPS.

The system is designed around a simple principle: **automatic mode maximizes evidence, manual mode maximizes speed.**

---

## ✨ 2. Features

- 🔊 Continuous audio monitoring with wake-word detection (trigger word: `blueberry`)
- 📸 Automatic photo capture on trigger via onboard ESP32-S3 camera
- 🎤 Audio evidence recording (`.wav`) alongside every automatic alert
- 📍 Real-time GPS location tracking in the mobile app
- 📲 Instant WhatsApp alerts with image, audio, location & timestamp
- ⚡ One-touch **Manual SOS** (2-second press) for fast, evidence-free alerts, independent of the hardware device
- 💓 Heartbeat-based ESP32-S3 connectivity status, shown separately from the app's internet connectivity status
- 👥 Priority-ordered emergency contacts (up to 5, reorderable, swipe-to-delete with confirmation)
- 📊 Alert history with Manual / Automatic / All filters + weekly stats
- ☁️ Realtime sync between hardware, backend, and mobile app via Firebase

---

## 🛠️ 3. Tech Stack

| Layer | Technology | Purpose |
|---|---|---|
| **Hardware** | XIAO ESP32-S3 Sense (Camera + PDM Mic) | Captures audio continuously & photo on trigger |
| **Firmware** | Arduino (C++), `esp_camera`, `ESP_I2S` | Records audio, controls camera, sends heartbeat |
| **Backend** | Node.js (Firebase Cloud Functions) — `index.js` | Processes audio, manages alerts, uploads media |
| **Speech-to-Text** | ElevenLabs API | Converts recorded audio to text for trigger detection |
| **Database** | Firebase Firestore | Stores alerts (classified automatic/manual), contacts & device status |
| **File Storage** | Firebase Storage | Stores captured images & `.wav` audio files |
| **Notifications** | CircuitDigest Cloud API | Sends WhatsApp alerts to emergency contacts |
| **Mobile App** | Flutter (Dart) | Home, History, and Contacts management UI |
| **Realtime Sync** | Firebase Firestore listeners | Live device status & alert history updates |

---

## 🧩 4. System Architecture

### 4.1 Component Architecture

```mermaid
flowchart TB
    subgraph HW["📡 Hardware — ESP32-S3"]
        A1["Mic — continuous<br/>5s audio capture"]
        A2["Camera — captures<br/>photo only on trigger"]
        A3["Heartbeat<br/>every 30s"]
    end

    subgraph MOB["📱 Flutter App"]
        M1["Home — device status,<br/>internet status, live GPS,<br/>contact count"]
        M2["Manual SOS<br/>(press & hold 2s)"]
        M3["History — Manual/<br/>Automatic/All + stats"]
        M4["Contacts — priority list<br/>1–5, reorder, swipe-delete"]
    end

    subgraph BE["☁️ Firebase Cloud Functions (asia-southeast1)"]
        B1["processAudio"]
        B2["uploadPhoto"]
        B3["heartbeat"]
    end

    subgraph EXT["External Services"]
        D1["ElevenLabs<br/>Speech-to-Text"]
        F1["CircuitDigest<br/>WhatsApp API"]
    end

    subgraph DATA["Firebase"]
        C1["Firestore<br/>alerts · contacts · device status"]
        E1["Storage<br/>images · .wav audio"]
    end

    A1 -->|audio clip| B1
    B1 --> D1
    D1 -->|transcript| B1
    B1 -->|trigger word found| A2
    A2 -->|JPEG photo| B2
    B1 -->|create alert: automatic| C1
    B1 -->|store audio| E1
    B2 -->|store photo, link to alert| E1
    B2 --> C1
    B1 --> F1
    B2 --> F1

    A3 --> B3
    B3 -->|update last-seen| C1

    M2 -->|GPS coords| C1
    M2 -->|trigger manual alert| F1

    C1 -.realtime sync.-> M1
    C1 -.realtime sync.-> M3
    C1 -.realtime sync.-> M4

    F1 -->|WhatsApp message| G["👤 Emergency Contact"]
```

> The ESP32-S3 only feeds the automatic path — audio to `processAudio`, photo to `uploadPhoto` — while the Flutter app's manual SOS writes straight to Firestore and triggers the WhatsApp send on its own, with no dependency on the hardware device. The app's Home, History, and Contacts pages all stay in sync via Firestore listeners.

### 4.2 Alert Flow — Automatic Mode

```mermaid
flowchart TD
    A["🎙️ ESP32-S3 records<br/>5s audio clip"] --> B["Backend (processAudio)<br/>sends clip to ElevenLabs"]
    B --> C{"Trigger word<br/>'blueberry' found?"}
    C -- No --> W["⏳ Wait 3s"] --> A
    C -- Yes --> D["📸 ESP32-S3<br/>captures photo"]
    D --> E["Backend creates alert<br/>(type: automatic) in Firestore"]
    E --> F["Audio + photo uploaded<br/>to Firebase Storage"]
    F --> G["WhatsApp alert sent<br/>via CircuitDigest"]
    G --> H["✅ Contact receives:<br/>image URL + audio (.wav)<br/>+ location + timestamp"]
```

### 4.3 Alert Flow — Manual Mode

```mermaid
flowchart TD
    I["📱 User holds SOS<br/>button for 2s"] --> J["Flutter app reads<br/>current GPS location"]
    J --> K["Alert created<br/>(type: manual) in Firestore"]
    K --> L["WhatsApp alert sent<br/>via CircuitDigest"]
    L --> M["✅ Contact receives:<br/>location + timestamp only<br/>(no image/audio)"]
```

> **Why two modes?** Automatic mode takes longer since it waits on audio recording, transcription, and photo/audio upload — but produces stronger evidence. Manual mode skips all of that and doesn't touch the ESP32-S3 at all, only needing the phone's internet and GPS, for near-instant delivery when every second counts. Each automatic listening cycle records for **5 seconds**, transcribes and checks for the trigger word, and if not found, **waits 3 seconds** before starting the next cycle.

---

## 🔩 5. Core Modules

### 5.1 Hardware — XIAO ESP32-S3 Sense

| Component | Detail |
|---|---|
| Microcontroller | ESP32-S3 (XIAO Sense variant) |
| Microphone | PDM mic via `ESP_I2S` — Clock: GPIO 42, Data: GPIO 41 |
| Camera | OV-series camera module (JPEG, VGA resolution, quality 12) |
| Sample Rate | 16 kHz, mono, 16-bit |
| Recording Window | 5 seconds per listening cycle, with a 3-second pause before the next cycle if no trigger word is found |
| Connectivity | Wi-Fi (HTTPS to Firebase Cloud Functions) |
| Heartbeat Interval | Every 30 seconds |

### 5.2 Backend — `index.js` (Firebase Cloud Functions, `asia-southeast1`)

| Endpoint | Responsibility |
|---|---|
| `processAudio` | Receives `.wav` audio, sends to ElevenLabs STT, checks for trigger word, creates alert in Firestore, stores audio in Storage, and triggers the WhatsApp alert via CircuitDigest |
| `uploadPhoto` | Receives JPEG photo, stores in Firebase Storage, links to alert, triggers WhatsApp send with the photo |
| `heartbeat` | Updates ESP32-S3's "last seen" timestamp in Firestore for online/offline status |

### 5.3 Mobile App — Flutter

| Page | Functionality |
|---|---|
| **Home** | Top banner shows **Connected / Disconnected** based on the phone's **internet connectivity** (so the user always knows if at least manual alerts can go through); separately reflects **ESP32-S3 device status** via its heartbeat; also shows live GPS location (updates only while online), current contact count, and the manual SOS button |
| **History** | Alert log filtered by Manual / Automatic / All, with total alerts & this-week stats |
| **Contacts** | Add, reorder (priority 1–5), and remove (swipe-to-delete with confirmation) emergency contacts |

---

## 📁 6. Project Structure

```
SheAlert/
├── firmware/
│   └── shealert_esp32s3/
│       └── shealert_esp32s3.ino        # Arduino firmware (mic + camera + heartbeat)
├── backend/
│   ├── index.js                        # Firebase Cloud Functions (processAudio, uploadPhoto, heartbeat)
│   ├── package.json
│   └── .env                            # API keys (ElevenLabs, CircuitDigest) — not committed
├── mobile_app/
│   └── shealert_flutter/
│       ├── lib/
│       │   ├── pages/
│       │   │   ├── home_page.dart
│       │   │   ├── history_page.dart
│       │   │   └── contacts_page.dart
│       │   └── main.dart
│       └── pubspec.yaml
├── docs/
│   └── screenshots/
└── README.md
```

> ⚠️ I don't have access to your actual repo, so I can't verify this tree matches. If you paste your real folder listing (e.g. `tree -L 3` output) or upload the repo, I'll check it against this and correct any mismatches.

---

## 📸 7. Screenshots / Demo

<!-- Add screenshots here: Home page (connected & disconnected states), History page, Contacts page, backend logs/console, and WhatsApp notification screenshots for both manual and automatic alerts -->

| Home (Connected) | Home (Disconnected) | History Page | Contacts Page |
|---|---|---|---|
| _add screenshot_ | _add screenshot_ | _add screenshot_ | _add screenshot_ |

| Backend Logs | WhatsApp Alert (Manual) | WhatsApp Alert (Automatic) |
|---|---|---|
| _add screenshot_ | _add screenshot_ | _add screenshot_ |

---

## 📊 8. Results

<!--
How to measure end-to-end latency when it's under a minute:
Report it in seconds, not forced into a minute format — e.g. "~38s avg" rather than "0.63 min".
To get real numbers, log a server timestamp at each stage and take the delta:
  1. t0 = ESP32-S3 starts recording (or manual SOS button press)
  2. t1 = processAudio (or manualAlert path) receives the request
  3. t2 = ElevenLabs transcript returned (automatic only)
  4. t3 = Firestore alert document created
  5. t4 = CircuitDigest WhatsApp API call returns success
Compute (t4 - t0) in milliseconds, convert to seconds, and average over ~10–15 trials for each mode.
Firestore server timestamps (FieldValue.serverTimestamp()) avoid clock-drift issues between device/backend/phone.
-->

- Average time from trigger word → WhatsApp alert (automatic mode): `TBD`
- Average time for manual SOS delivery: `TBD`
- Trigger word detection accuracy (test runs): `TBD`
- Device uptime / heartbeat reliability: `TBD`

---

## 🎯 9. Key Learnings

- Streaming and buffering audio from the ESP32-S3's PDM mic via `ESP_I2S` in fixed 5-second windows, and the trade-offs of that window size between responsiveness and transcription accuracy
- Designing for two very different latency budgets in one app — automatic mode optimized for evidence richness, manual mode optimized for raw speed — and making that trade-off explicit in the UX rather than hiding it
- Working with Firebase Cloud Functions regions (`asia-southeast1`) and structuring endpoints (`processAudio`, `uploadPhoto`, `heartbeat`) around distinct hardware/app triggers instead of one monolithic function
- Integrating third-party APIs (ElevenLabs STT, CircuitDigest WhatsApp) into a real-time pipeline, including handling their failure modes without blocking the alert flow
- Using Firestore listeners for realtime sync across three independent surfaces (Home, History, Contacts) so the app reflects hardware and backend state changes without polling
- Distinguishing "device connectivity" (ESP32-S3 heartbeat) from "app connectivity" (phone's internet) as two separate signals, since manual SOS only needs the latter

---

## 🚀 10. Future Improvements

- 🔋 Battery-optimized / low-power listening mode for the ESP32-S3
- 🗣️ On-device wake-word detection to reduce cloud STT calls
- 🌐 Offline SMS fallback when there's no internet connectivity
- 🧭 Geofencing-based automatic alerts (e.g., unsafe zone detection)
- 📈 Analytics dashboard for alert trends over time
- 🔐 Add user authentication (currently single-user, no login)

---

## 🙋 Author

**Thirumalai Subashree**
