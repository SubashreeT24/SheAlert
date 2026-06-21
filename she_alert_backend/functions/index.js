require('dotenv').config();
const functions = require('firebase-functions');
const fetch = require('node-fetch');
const FormData = require('form-data');tou

const ELEVENLABS_API_KEY = process.env.ELEVENLABS_API_KEY;

function detectTrigger(transcript, triggerWord = 'blueberry') {
  const text = transcript.toLowerCase();
  const triggerHit = text.includes(triggerWord.toLowerCase());
  const helpCount = (text.match(/\bhelp\b/g) || []).length;
  return triggerHit || helpCount >= 2;
}

async function transcribeAudio(audioBuffer) {
  const form = new FormData();
  form.append('file', audioBuffer, { filename: 'audio.wav' });
  form.append('model_id', 'scribe_v1');

  const res = await fetch('https://api.elevenlabs.io/v1/speech-to-text', {
    method: 'POST',
    headers: { 'xi-api-key': ELEVENLABS_API_KEY },
    body: form,
  });
  const data = await res.json();
  return data.text;
}

exports.processAudio = functions.https.onRequest(async (req, res) => {
  try {
    const transcript = await transcribeAudio(req.rawBody);
    const triggered = detectTrigger(transcript);

    res.json({ transcript, triggered });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: err.message });
  }
});