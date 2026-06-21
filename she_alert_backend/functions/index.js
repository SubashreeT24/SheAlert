require('dotenv').config();

if (process.env.FUNCTIONS_EMULATOR === 'true') {
  process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8080';
}

const functions = require('firebase-functions');
const fetch = require('node-fetch');
const FormData = require('form-data');
const cloudinary = require('cloudinary').v2;
const admin = require('firebase-admin');
const { FieldValue } = require('firebase-admin/firestore');

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

const ELEVENLABS_API_KEY = process.env.ELEVENLABS_API_KEY;

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

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

  if (!res.ok) {
    console.error('ElevenLabs error:', data);
    throw new Error(data.detail?.message || data.message || 'Transcription failed');
  }

  return data.text;
}

async function uploadImage(filePath) {
  const result = await cloudinary.uploader.upload(filePath, {
    folder: 'shealert',
  });
  return result.secure_url;
}

// Uploads a raw image buffer (instead of a local file path).
// This is what the real ESP32 photo (or harness test photo) will use.
async function uploadImageBuffer(buffer) {
  const base64 = `data:image/jpeg;base64,${buffer.toString('base64')}`;
  const result = await cloudinary.uploader.upload(base64, {
    folder: 'shealert',
  });
  return result.secure_url;
}

exports.processAudio = functions.https.onRequest(async (req, res) => {
  try {
    console.log('Body size:', req.rawBody ? req.rawBody.length : 'no body received');

    if (!req.rawBody || req.rawBody.length === 0) {
      return res.status(400).json({ error: 'No audio data received in request body' });
    }

    const transcript = await transcribeAudio(req.rawBody);
    console.log('Transcript:', transcript);

    const triggered = detectTrigger(transcript);

    if (!triggered) {
      return res.json({ transcript, triggered });
    }

    // Trigger detected. No image yet — the device (or harness, for now)
    // sends the photo in a SEPARATE request to uploadPhoto below.
    // imageUrl stays null until that happens, so status: 'pending_photo'
    // is actually true at the moment this doc is created.
    const alertDoc = await db.collection('alerts').add({
      transcript,
      triggered,
      imageUrl: null,
      status: 'pending_photo',
      timestamp: FieldValue.serverTimestamp(),
    });
    console.log('Alert written with ID:', alertDoc.id);

    return res.json({ transcript, triggered, imageUrl: null, alertId: alertDoc.id });
  } catch (err) {
    console.error('processAudio error:', err);
    return res.status(500).json({
      error: err.message || 'Unknown error',
      details: JSON.stringify(err, Object.getOwnPropertyNames(err)),
    });
  }
});

// Step 2 of the pipeline. Called separately, once the photo is actually
// available — later this will be the ESP32 POSTing its captured image.
// Requires the alertId so we know which Firestore doc to update.
exports.uploadPhoto = functions.https.onRequest(async (req, res) => {
  try {
    const alertId = req.query.alertId;

    if (!alertId) {
      return res.status(400).json({ error: 'Missing alertId query param' });
    }

    if (!req.rawBody || req.rawBody.length === 0) {
      return res.status(400).json({ error: 'No image data received in request body' });
    }

    const alertRef = db.collection('alerts').doc(alertId);
    const alertSnap = await alertRef.get();

    if (!alertSnap.exists) {
      return res.status(404).json({ error: `No alert found with id ${alertId}` });
    }

    const imageUrl = await uploadImageBuffer(req.rawBody);
    console.log('Image uploaded:', imageUrl);

    await alertRef.update({
      imageUrl,
      status: 'complete',
    });

    return res.json({ alertId, imageUrl, status: 'complete' });
  } catch (err) {
    console.error('uploadPhoto error:', err);
    return res.status(500).json({
      error: err.message || 'Unknown error',
      details: JSON.stringify(err, Object.getOwnPropertyNames(err)),
    });
  }
});