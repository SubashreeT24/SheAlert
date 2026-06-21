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
const CIRCUITDIGEST_API_KEY = process.env.CIRCUITDIGEST_API_KEY;
const CIRCUITDIGEST_PHONE_NUMBER = process.env.CIRCUITDIGEST_PHONE_NUMBER;

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

// Reads the user's last known GPS location (written by the Flutter app,
// later). For now, returns a Firestore GeoPoint from a manually-faked doc.
// NOTE: collection name is lowercase "users" — must match Firestore data
// exactly (Firestore collection names are case-sensitive). If you seed
// test data via the Emulator UI, make sure it's created under "users",
// not "Users".
async function getLastKnownLocation(userId) {
  const userDoc = await db.collection('users').doc(userId).get();
  if (!userDoc.exists) return null;
  return userDoc.data().lastKnownLocation || null;
}

// Sends a WhatsApp alert via CircuitDigest Cloud using the
// "image_capture_alert" template. The template only supports fixed text
// variables (no native image attachment), so we embed the Cloudinary
// image link as text inside event_type, and a Google Maps link inside
// location.
async function sendWhatsAppAlert({ imageUrl, location, timestamp }) {
  const mapsLink = location
    ? `https://maps.google.com/?q=${location.latitude},${location.longitude}`
    : 'Location unavailable';

  const payload = {
    phone_number: CIRCUITDIGEST_PHONE_NUMBER,
    template_id: 'image_capture_alert',
    variables: {
      event_type: `SOS Triggered - Photo: ${imageUrl}`,
      location: mapsLink,
      device_name: 'SheAlert',
      captured_time: timestamp,
    },
  };

  const res = await fetch('https://www.circuitdigest.cloud/api/v1/whatsapp/send', {
    method: 'POST',
    headers: {
      'X-API-Key': CIRCUITDIGEST_API_KEY,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload),
  });

  const data = await res.json();
  if (!res.ok) {
    console.error('CircuitDigest error:', data);
    throw new Error(data.message || 'WhatsApp alert failed');
  }
  console.log('WhatsApp alert sent:', data);
  return data;
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
    const location = await getLastKnownLocation('testuser1');
    console.log('Location fetched:', location ? `${location.latitude}, ${location.longitude}` : null);

    const alertDoc = await db.collection('alerts').add({
      transcript,
      triggered,
      imageUrl: null,
      location,
      status: 'pending_photo',
      timestamp: FieldValue.serverTimestamp(),
    });
    console.log('Alert written with ID:', alertDoc.id);

    return res.json({
      transcript,
      triggered,
      imageUrl: null,
      location: location ? { lat: location.latitude, lng: location.longitude } : null,
      alertId: alertDoc.id,
    });
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

    // Fire the WhatsApp alert now that photo + location + timestamp are ready
    try {
      await sendWhatsAppAlert({
        imageUrl,
        location: alertSnap.data().location,
        timestamp: new Date().toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' }),
      });
    } catch (alertErr) {
      console.error('Failed to send WhatsApp alert:', alertErr.message);
      // Don't fail the whole request just because the alert send failed
    }

    return res.json({ alertId, imageUrl, status: 'complete' });
  } catch (err) {
    console.error('uploadPhoto error:', err);
    return res.status(500).json({
      error: err.message || 'Unknown error',
      details: JSON.stringify(err, Object.getOwnPropertyNames(err)),
    });
  }
});