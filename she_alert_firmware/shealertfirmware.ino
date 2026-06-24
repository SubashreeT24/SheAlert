#include <WiFi.h>
#include <HTTPClient.h>
#include "ESP_I2S.h"
#include "esp_camera.h"
#include <ArduinoJson.h>

// ─────────────────────────────────────────────
//  CONFIG
// ─────────────────────────────────────────────

#define WIFI_SSID       "EVOLVE ROBOT LAB 2.4"
#define WIFI_PASSWORD   "7358006064"
#define USER_ID         "testuser1"

// ── Backend URLs ──
const char* PROCESS_AUDIO_URL = "https://asia-southeast1-shealert-222cc.cloudfunctions.net/processAudio";
const char* UPLOAD_PHOTO_URL  = "https://asia-southeast1-shealert-222cc.cloudfunctions.net/uploadPhoto";
const char* HEARTBEAT_URL     = "https://asia-southeast1-shealert-222cc.cloudfunctions.net/heartbeat";

// ─────────────────────────────────────────────
//  MIC PINS & CONFIG
// ─────────────────────────────────────────────

const int8_t  I2S_CLK        = 42;
const int8_t  I2S_DIN        = 41;
const uint32_t SAMPLE_RATE   = 16000;
const int      RECORD_SECONDS = 5;
const int      TOTAL_SAMPLES  = SAMPLE_RATE * RECORD_SECONDS;

I2SClass I2S;

// ─────────────────────────────────────────────
//  CAMERA PINS (XIAO ESP32S3 Sense)
// ─────────────────────────────────────────────

#define PWDN_GPIO_NUM   -1
#define RESET_GPIO_NUM  -1
#define XCLK_GPIO_NUM   10
#define SIOD_GPIO_NUM   40
#define SIOC_GPIO_NUM   39
#define Y9_GPIO_NUM     48
#define Y8_GPIO_NUM     11
#define Y7_GPIO_NUM     12
#define Y6_GPIO_NUM     14
#define Y5_GPIO_NUM     16
#define Y4_GPIO_NUM     18
#define Y3_GPIO_NUM     17
#define Y2_GPIO_NUM     15
#define VSYNC_GPIO_NUM  38
#define HREF_GPIO_NUM   47
#define PCLK_GPIO_NUM   13

// ─────────────────────────────────────────────
//  WAV HEADER
// ─────────────────────────────────────────────

void writeWavHeader(uint8_t* header, int dataSize) {
  int totalSize = dataSize + 36;
  int byteRate  = SAMPLE_RATE * 2;

  header[0]='R'; header[1]='I'; header[2]='F'; header[3]='F';
  header[4]=(totalSize)&0xff;       header[5]=(totalSize>>8)&0xff;
  header[6]=(totalSize>>16)&0xff;   header[7]=(totalSize>>24)&0xff;
  header[8]='W'; header[9]='A'; header[10]='V'; header[11]='E';

  header[12]='f'; header[13]='m'; header[14]='t'; header[15]=' ';
  header[16]=16; header[17]=0; header[18]=0; header[19]=0;
  header[20]=1;  header[21]=0;
  header[22]=1;  header[23]=0;
  header[24]=(SAMPLE_RATE)&0xff;     header[25]=(SAMPLE_RATE>>8)&0xff;
  header[26]=(SAMPLE_RATE>>16)&0xff; header[27]=(SAMPLE_RATE>>24)&0xff;
  header[28]=(byteRate)&0xff;        header[29]=(byteRate>>8)&0xff;
  header[30]=(byteRate>>16)&0xff;    header[31]=(byteRate>>24)&0xff;
  header[32]=2; header[33]=0;
  header[34]=16; header[35]=0;

  header[36]='d'; header[37]='a'; header[38]='t'; header[39]='a';
  header[40]=(dataSize)&0xff;        header[41]=(dataSize>>8)&0xff;
  header[42]=(dataSize>>16)&0xff;    header[43]=(dataSize>>24)&0xff;
}

// ─────────────────────────────────────────────
//  CAMERA INIT
// ─────────────────────────────────────────────

bool initCamera() {
  camera_config_t config;
  config.ledc_channel = LEDC_CHANNEL_0;
  config.ledc_timer   = LEDC_TIMER_0;
  config.pin_d0       = Y2_GPIO_NUM;
  config.pin_d1       = Y3_GPIO_NUM;
  config.pin_d2       = Y4_GPIO_NUM;
  config.pin_d3       = Y5_GPIO_NUM;
  config.pin_d4       = Y6_GPIO_NUM;
  config.pin_d5       = Y7_GPIO_NUM;
  config.pin_d6       = Y8_GPIO_NUM;
  config.pin_d7       = Y9_GPIO_NUM;
  config.pin_xclk     = XCLK_GPIO_NUM;
  config.pin_pclk     = PCLK_GPIO_NUM;
  config.pin_vsync    = VSYNC_GPIO_NUM;
  config.pin_href     = HREF_GPIO_NUM;
  config.pin_sccb_sda = SIOD_GPIO_NUM;
  config.pin_sccb_scl = SIOC_GPIO_NUM;
  config.pin_pwdn     = PWDN_GPIO_NUM;
  config.pin_reset    = RESET_GPIO_NUM;
  config.xclk_freq_hz = 20000000;
  config.pixel_format = PIXFORMAT_JPEG;
  config.frame_size   = FRAMESIZE_VGA;
  config.jpeg_quality = 12;
  config.fb_count     = 1;

  esp_err_t err = esp_camera_init(&config);
  if (err != ESP_OK) {
    Serial.printf("❌ Camera init failed: 0x%x\n", err);
    return false;
  }
  Serial.println("✅ Camera ready!");
  return true;
}

// ─────────────────────────────────────────────
//  HEARTBEAT
// ─────────────────────────────────────────────

void sendHeartbeat() {
  HTTPClient hb;
  String url = String(HEARTBEAT_URL) + "?userId=" + USER_ID;
  hb.begin(url);
  hb.setTimeout(5000);
  int code = hb.GET();
  hb.end();
  if (code == 200) {
    Serial.println("💓 Heartbeat sent — device online");
  } else {
    Serial.println("⚠️ Heartbeat failed: " + String(code));
  }
}

// ─────────────────────────────────────────────
//  CAPTURE & UPLOAD PHOTO
// ─────────────────────────────────────────────

void captureAndUploadPhoto(const char* alertId) {
  Serial.println("📸 Capturing photo...");

  camera_fb_t* fb = esp_camera_fb_get();
  if (!fb) {
    Serial.println("❌ Camera capture failed!");
    return;
  }
  Serial.println("✅ Photo captured! Size: " + String(fb->len) + " bytes");

  String uploadUrl = String(UPLOAD_PHOTO_URL) + "?alertId=" + String(alertId);

  Serial.println("📤 Uploading photo to backend...");

  HTTPClient http;
  http.begin(uploadUrl);
  http.addHeader("Content-Type", "image/jpeg");
  http.setTimeout(30000);

  int responseCode = http.POST(fb->buf, fb->len);
  esp_camera_fb_return(fb);

  Serial.println("Upload response code: " + String(responseCode));

  if (responseCode == 200) {
    String responseBody = http.getString();
    Serial.println("Upload response: " + responseBody);

    JsonDocument doc;
    deserializeJson(doc, responseBody);

    const char* imageUrl = doc["imageUrl"];
    const char* audioUrl = doc["audioUrl"];
    const char* status   = doc["status"];

    Serial.println("✅ Photo uploaded!");
    Serial.println("🖼  Image URL: " + String(imageUrl));
    Serial.println("🎤 Audio URL: " + String(audioUrl ? audioUrl : "none"));
    Serial.println("📋 Status: " + String(status));
    Serial.println("📱 WhatsApp alert sent to all contacts with photo + audio!");
  } else {
    Serial.println("❌ Photo upload failed: " + http.getString());
  }

  http.end();
}

// ─────────────────────────────────────────────
//  SETUP
// ─────────────────────────────────────────────

void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println("Connecting to WiFi...");
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\n✅ WiFi connected! IP: " + WiFi.localIP().toString());

  I2S.setPinsPdmRx(I2S_CLK, I2S_DIN);
  if (!I2S.begin(I2S_MODE_PDM_RX, SAMPLE_RATE, I2S_DATA_BIT_WIDTH_16BIT, I2S_SLOT_MODE_MONO)) {
    Serial.println("❌ Microphone not found!");
    while (1);
  }
  Serial.println("✅ Microphone ready!");

  if (!initCamera()) {
    Serial.println("❌ Camera failed — halting.");
    while (1);
  }

  // Send first heartbeat immediately on startup
  sendHeartbeat();

  Serial.println("\n🟢 SheAlert hardware ready! Listening...\n");
}

// ─────────────────────────────────────────────
//  MAIN LOOP
// ─────────────────────────────────────────────

void loop() {
  // ── Heartbeat every 30 seconds ──
  static unsigned long lastHeartbeat = 0;
  if (millis() - lastHeartbeat > 30000) {
    sendHeartbeat();
    lastHeartbeat = millis();
  }

  // ── Step 1: Record audio ──
  int dataSize = TOTAL_SAMPLES * 2;
  int wavSize  = dataSize + 44;

  uint8_t* wavBuffer = (uint8_t*)malloc(wavSize);
  if (!wavBuffer) {
    Serial.println("❌ Not enough memory for audio buffer!");
    delay(3000);
    return;
  }

  writeWavHeader(wavBuffer, dataSize);
  int16_t* audioData = (int16_t*)(wavBuffer + 44);

  Serial.println("🎤 Recording... speak now!");
  for (int i = 0; i < TOTAL_SAMPLES; i++) {
    audioData[i] = (int16_t)I2S.read();
    if (i % SAMPLE_RATE == 0) {
      Serial.println("⏳ " + String(i / SAMPLE_RATE) + "/" + String(RECORD_SECONDS) + "s");
    }
  }
  Serial.println("🎤 Recording complete!");

  // ── Step 2: Send audio to backend ──
  String processUrl = String(PROCESS_AUDIO_URL) + "?userId=" + USER_ID;

  Serial.println("📤 Sending audio to backend...");

  HTTPClient http;
  http.begin(processUrl);
  http.addHeader("Content-Type", "audio/wav");
  http.setTimeout(30000);

  int responseCode = http.POST(wavBuffer, wavSize);
  free(wavBuffer);

  Serial.println("Audio response code: " + String(responseCode));

  if (responseCode == 200) {
    String responseBody = http.getString();
    Serial.println("Audio response: " + responseBody);

    JsonDocument doc;
    DeserializationError error = deserializeJson(doc, responseBody);

    if (!error) {
      const char* transcript = doc["transcript"] | "";
      bool triggered         = doc["triggered"]  | false;
      const char* alertId    = doc["alertId"]    | "";

      Serial.println("📝 Transcript: \"" + String(transcript) + "\"");

      if (triggered && strlen(alertId) > 0) {
        Serial.println("🚨 TRIGGER DETECTED! AlertId: " + String(alertId));
        http.end();
        captureAndUploadPhoto(alertId);
        Serial.println("\n✅ Full SOS flow complete! Resuming listening...\n");
      } else {
        Serial.println("✅ No trigger. Listening again...");
      }
    } else {
      Serial.println("❌ JSON parse error: " + String(error.c_str()));
    }
  } else {
    Serial.println("❌ Backend error: " + http.getString());
  }

  http.end();

  Serial.println("⏸  Waiting 3s before next recording...\n");
  delay(3000);
}
