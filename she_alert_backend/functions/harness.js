const fs = require('fs');
const fetch = require('node-fetch');

const PROJECT_BASE = 'https://asia-southeast1-shealert-222cc.cloudfunctions.net';

async function simulateDevice() {
  // Step 1: send audio, get back alertId (if triggered)
  const audio = fs.readFileSync('D:\\Downloads\\record_out.wav');
  const audioRes = await fetch(PROJECT_BASE + '/processAudio', {
    method: 'POST',
    headers: { 'Content-Type': 'audio/wav' },
    body: audio,
  });
  const audioData = await audioRes.json();
  console.log('processAudio response:', audioData);

  if (!audioData.triggered || !audioData.alertId) {
    console.log('Not triggered, or no alertId — stopping here.');
    return;
  }

  // Step 2: simulate the photo arriving moments later (separate request,
  // same as the ESP32 will do once it captures and sends its own photo).
  const image = fs.readFileSync('C:\\Users\\THIRUMALAI\\Pictures\\Camera Roll\\nature.jpg');
  const photoRes = await fetch(PROJECT_BASE + '/uploadPhoto?alertId=' + audioData.alertId, {
    method: 'POST',
    headers: { 'Content-Type': 'image/jpeg' },
    body: image,
  });
  const photoData = await photoRes.json();
  console.log('uploadPhoto response:', photoData);
}

simulateDevice();