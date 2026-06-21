const fs = require('fs');
const fetch = require('node-fetch');

async function simulateDevice() {
  const audio = fs.readFileSync('D:\\Downloads\\record_out.wav');
  const res = await fetch('http://127.0.0.1:5001/shealert-222cc/us-central1/processAudio', {
    method: 'POST',
    headers: { 'Content-Type': 'audio/wav' },
    body: audio,
  });
  const text = await res.text();
  console.log(text);
}

simulateDevice();