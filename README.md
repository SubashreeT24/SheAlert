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
- 🆘 **Manual Mode** — A press-and-hold SOS button in the companion Flutter app for situations where speed matters more than evidence, sending just live location and timestamp.

The system is designed around a simple principle: **automatic mode maximizes evidence, manual mode maximizes speed.**

---

## ✨ 2. Features

- 🔊 Continuous audio monitoring with wake-word detection (trigger word: `blueberry`)
- 📸 Automatic photo capture on trigger via onboard ESP32-S3 camera
- 🎤 Audio evidence recording (`.wav`) alongside every automatic alert
- 📍 Real-time GPS location tracking in the mobile app
- 📲 Instant WhatsApp alerts with image, audio, location & timestamp
- ⚡ One-touch **Manual SOS** (2-second press) for fast, evidence-free alerts
- 💓 Heartbeat-based device connectivity status (device online/offline)
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
| **Database** | Firebase Firestore | Stores alerts (classified automatic/manual) & contacts |
| **File Storage** | Firebase Storage | Stores captured images & `.wav` audio files |
| **Notifications** | CircuitDigest Cloud API | Sends WhatsApp alerts to emergency contacts |
| **Mobile App** | Flutter (Dart) | Home, History, and Contacts management UI |
| **Realtime Sync** | Firebase Firestore listeners | Live device status & alert history updates |

---

## 🧩 4. System Architecture

### 4.1 Component Architecture

```mermaid
%%{init: {"flowchart": {"nodeSpacing": 45, "rankSpacing": 60, "htmlLabels": true}}}%%
graph LR
    subgraph Hardware["🔌 Hardware"]
        ESP["XIAO ESP32-S3<br/>Mic + Camera"]
    end

    subgraph Backend["☁️ Backend — index.js"]
        PA["processAudio()"]
        UP["uploadPhoto()"]
        HB["heartbeat()"]
    end

    subgraph FB["🔥 Firebase"]
        FS[("Firestore<br/>alerts + contacts")]
        ST[("Storage<br/>images + audio")]
    end

    subgraph External["🌐 External APIs"]
        EL["ElevenLabs<br/>Speech-to-Text"]
        CD["CircuitDigest<br/>WhatsApp API"]
    end

    subgraph Mobile["📱 Flutter App"]
        FL["Home / History<br/>/ Contacts"]
    end

    ESP -->|"5s audio<br/>clip"| PA
    PA --> EL
    EL -->|"transcript"| PA
    PA -->|"trigger found:<br/>create alert<br/>(automatic)"| FS
    PA -->|"store<br/>audio .wav"| ST
    PA -->|"send WhatsApp<br/>audio + loc + time"| CD
    PA -->|"alertId"| ESP
    ESP -->|"captured<br/>photo"| UP
    UP -->|"store<br/>photo"| ST
    UP -->|"update alert<br/>with photo URL"| FS
    UP -->|"send WhatsApp<br/>image"| CD
    ESP -->|"heartbeat<br/>every 30s"| HB
    HB -->|"update<br/>last-seen"| FS
    FL -->|"manual trigger:<br/>create alert<br/>(manual)"| FS
    FL -->|"send WhatsApp<br/>loc + time"| CD
    FS <-->|"realtime<br/>listeners"| FL
```

> `processAudio` handles the trigger detection, creates the alert, stores the `.wav` in Storage, and sends the first WhatsApp message (audio + location + timestamp). `uploadPhoto` then stores the photo, updates that same alert with the photo URL, and sends the image over WhatsApp too. Firestore is mainly the source of truth for alerts (tagged automatic/manual) and contacts — both of which the Flutter app listens to in realtime.

### 4.2 Alert Flow — Automatic Mode

```mermaid
%%{init: {"flowchart": {"nodeSpacing": 40, "rankSpacing": 50, "htmlLabels": true}}}%%
flowchart TD
    A["🎙️ Record 5s<br/>audio clip"] --> B["Send to<br/>processAudio()"]
    B --> C["ElevenLabs<br/>transcribes clip"]
    C --> D{"Trigger word<br/>'blueberry'<br/>found?"}
    D -- No --> W["⏳ Wait 3s"] --> A
    D -- Yes --> E["Create alert<br/>in Firestore<br/>(automatic)"]
    E --> F["Store audio .wav<br/>in Storage"]
    F --> G["Send WhatsApp<br/>audio + loc + time"]
    G --> H["📸 Capture photo"]
    H --> I["Store photo<br/>in Storage"]
    I --> J["Update alert +<br/>send WhatsApp image"]
    J --> K["✅ Contact has full<br/>evidence + location"]
```

### 4.3 Alert Flow — Manual Mode

```mermaid
%%{init: {"flowchart": {"nodeSpacing": 40, "rankSpacing": 50, "htmlLabels": true}}}%%
flowchart TD
    L["📱 Hold SOS<br/>button (2s)"] --> M["Get live<br/>GPS location"]
    M --> N["Create alert<br/>in Firestore<br/>(manual)"]
    N --> O["Send WhatsApp<br/>loc + time"]
    O --> P["✅ Contact gets<br/>location, no media"]
```

> **Why two modes?** Automatic mode takes longer since it waits on audio recording, transcription, storage, and photo upload — but produces stronger evidence. Manual mode skips all of that for near-instant delivery when every second counts.
>
> Each automatic listening cycle: **record 5 seconds → transcribe → check for the trigger word → if not found, wait 3 seconds → start the next recording cycle.**

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
| `processAudio` | Receives `.wav` audio, sends to ElevenLabs STT, checks for trigger word, creates alert in Firestore, stores audio in Storage, and sends the first WhatsApp alert via CircuitDigest |
| `uploadPhoto` | Receives JPEG photo, stores in Firebase Storage, updates the alert with the photo URL, and sends the follow-up WhatsApp alert with the image |
| `heartbeat` | Updates device "last seen" timestamp in Firestore for online/offline status |

### 5.3 Mobile App — Flutter

| Page | Functionality |
|---|---|
| **Home** | Connection status (device + internet), live GPS location, contact count, manual SOS button |
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

> ⚠️ I still can't check this against your real repo — I don't have access to it. Paste your actual folder listing (e.g. `tree -L 3` output) or upload the project and I'll verify/correct this section for you.

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
Measuring end-to-end latency when it's under a minute: report it in seconds (e.g. "~38s avg"), not forced into minute format.
Log a server timestamp at each stage and take the delta:
  1. t0 = ESP32-S3 starts recording (or manual SOS button press)
  2. t1 = processAudio (or manual path) receives the request
  3. t2 = ElevenLabs transcript returned (automatic only)
  4. t3 = Firestore alert document created
  5. t4 = CircuitDigest WhatsApp API call returns success
Compute (t4 - t0) in ms, convert to seconds, average over ~10-15 trials per mode.
Use Firestore's FieldValue.serverTimestamp() to avoid clock drift between device/backend/phone.
-->

- Average time from trigger word → WhatsApp alert (automatic mode): `TBD`
- Average time for manual SOS delivery: `TBD`
- Trigger word detection accuracy (test runs): `TBD`
- Device uptime / heartbeat reliability: `TBD`

---

## 🎯 9. Key Learnings

- Streaming and buffering audio from the ESP32-S3's PDM mic via `ESP_I2S` in fixed 5-second windows, and balancing that window size against transcription accuracy
- Designing for two very different latency budgets in one app — automatic mode optimized for evidence richness, manual mode optimized for raw speed — and making that trade-off explicit in the UX
- Working with Firebase Cloud Functions regions (`asia-southeast1`) and splitting responsibilities across `processAudio`, `uploadPhoto`, and `heartbeat` instead of one monolithic function
- Integrating third-party APIs (ElevenLabs STT, CircuitDigest WhatsApp) into a real-time pipeline, including handling their failure modes without blocking the rest of the alert flow
- Using Firestore listeners for realtime sync across Home, History, and Contacts so the app reflects hardware and backend state changes without polling
- Sequencing a single alert across two backend calls (`processAudio` then `uploadPhoto`) that both write to the same Firestore document without overwriting each other's data

---

## 🚀 10. Future Improvements

- 🔐 Add user authentication (currently single-user, no login)
- 🔋 Battery-optimized / low-power listening mode for the ESP32-S3
- 🗣️ On-device wake-word detection to reduce cloud STT calls
- 🌐 Offline SMS fallback when there's no internet connectivity
- 🧭 Geofencing-based automatic alerts (e.g., unsafe zone detection)
- 📈 Analytics dashboard for alert trends over time

---

## 🙋 Author

**Thirumalai Subashree**
