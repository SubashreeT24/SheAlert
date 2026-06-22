require('dotenv').config();

const { onRequest } = require('firebase-functions/v2/https');
const { setGlobalOptions } = require('firebase-functions/v2');
const functions = require('firebase-functions');
const fetch = require('node-fetch');
const FormData = require('form-data');
const admin = require('firebase-admin');
const { FieldValue } = require('firebase-admin/firestore');

setGlobalOptions({ region: 'asia-southeast1' });

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const storage = admin.storage();

const ELEVENLABS_API_KEY =
  process.env.ELEVENLABS_API_KEY || functions.config().elevenlabs.key;
const CIRCUITDIGEST_API_KEY =
  process.env.CIRCUITDIGEST_API_KEY || functions.config().circuitdigest.key;

const EMERGENCY_CONTACTS = [
  process.env.CIRCUITDIGEST_PHONE_NUMBER_1 || functions.config().circuitdigest.phone1,
  process.env.CIRCUITDIGEST_PHONE_NUMBER_2 || functions.config().circuitdigest.phone2,
];

// ─────────────────────────────────────────────
//  HELPERS
// ─────────────────────────────────────────────

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

async function uploadImageBuffer(buffer, alertId) {
  const bucket = storage.bucket();
  const fileName = 'alerts/' + alertId + '/photo.jpg';
  const file = bucket.file(fileName);

  await file.save(buffer, {
    metadata: {
      contentType: 'image/jpeg',
      customTime: new Date().toISOString(),
    },
  });

  await file.makePublic();
  const publicUrl =
    'https://storage.googleapis.com/' + bucket.name + '/' + fileName;
  return publicUrl;
}

async function getLastKnownLocation(userId) {
  const userDoc = await db.collection('users').doc(userId).get();
  if (!userDoc.exists) return null;
  return userDoc.data().lastKnownLocation || null;
}

async function sendWhatsAppAlert({ imageUrl, location, timestamp, phoneNumber, alertType }) {
  const mapsLink =
    location
      ? 'https://maps.google.com/?q=' + location.latitude + ',' + location.longitude
      : 'Location unavailable';

  const eventType =
    alertType === 'manual'
      ? 'SOS Triggered Manually'
      : imageUrl
      ? 'SOS Triggered - Photo: ' + imageUrl
      : 'SOS Triggered - No photo';

  const payload = {
    phone_number: phoneNumber,
    template_id: 'image_capture_alert',
    variables: {
      event_type: eventType,
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
    console.error('CircuitDigest error for ' + phoneNumber + ':', data);
    throw new Error(data.message || 'WhatsApp alert failed');
  }
  console.log('WhatsApp alert sent to ' + phoneNumber + ':', data);
  return data;
}

async function sendAlertToAllContacts({ imageUrl, location, timestamp, alertType }) {
  const results = await Promise.allSettled(
    EMERGENCY_CONTACTS.filter(Boolean).map(function (phoneNumber) {
      return sendWhatsAppAlert({ imageUrl, location, timestamp, phoneNumber, alertType });
    })
  );

  let successCount = 0;
  results.forEach(function (result, i) {
    if (result.status === 'fulfilled') {
      successCount++;
    } else {
      console.error('Failed to alert contact ' + (i + 1) + ':', result.reason);
    }
  });

  return successCount;
}

// ─────────────────────────────────────────────
//  1. MANUAL ALERT  (SOS hold button in app)
// ─────────────────────────────────────────────

exports.manualAlert = onRequest(async function (req, res) {
  try {
    if (req.method !== 'POST') {
      return res.status(405).json({ error: 'Method not allowed' });
    }

    const { userId, location } = req.body;

    if (!userId) {
      return res.status(400).json({ error: 'Missing userId in request body' });
    }

    console.log('Manual SOS triggered by userId:', userId);
    console.log('Location:', location || 'not provided — will fetch from Firestore');

    // Use provided location or fall back to last known from Firestore
    let resolvedLocation = location || null;
    if (!resolvedLocation) {
      resolvedLocation = await getLastKnownLocation(userId);
      console.log('Fetched last known location:', resolvedLocation);
    }

    const timestamp = new Date().toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' });

    // Save alert to Firestore
    const alertDoc = await db.collection('alerts').add({
      userId,
      type: 'manual',
      triggered: true,
      imageUrl: null,
      location: resolvedLocation,
      status: 'sent',
      timestamp: FieldValue.serverTimestamp(),
    });

    console.log('Manual alert saved with ID:', alertDoc.id);

    // Send WhatsApp to all emergency contacts
    const sent = await sendAlertToAllContacts({
      imageUrl: null,
      location: resolvedLocation,
      timestamp,
      alertType: 'manual',
    });

    return res.json({
      success: true,
      alertId: alertDoc.id,
      sent,
      message: sent > 0
        ? 'Alert sent to ' + sent + ' contact(s)'
        : 'Alert saved but no contacts were notified',
    });
  } catch (err) {
    console.error('manualAlert error:', err);
    return res.status(500).json({
      error: err.message || 'Unknown error',
      details: JSON.stringify(err, Object.getOwnPropertyNames(err)),
    });
  }
});

// ─────────────────────────────────────────────
//  2. PROCESS AUDIO  (automatic voice trigger)
// ─────────────────────────────────────────────

exports.processAudio = onRequest(async function (req, res) {
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

    const location = await getLastKnownLocation('testuser1');
    console.log(
      'Location fetched:',
      location ? location.latitude + ', ' + location.longitude : null
    );

    const alertDoc = await db.collection('alerts').add({
      userId: 'testuser1',
      type: 'automatic',
      transcript,
      triggered,
      imageUrl: null,
      location,
      status: 'pending_photo',
      timestamp: FieldValue.serverTimestamp(),
    });

    console.log('Automatic alert written with ID:', alertDoc.id);

    return res.json({
      transcript,
      triggered,
      imageUrl: null,
      location: location
        ? { lat: location.latitude, lng: location.longitude }
        : null,
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

// ─────────────────────────────────────────────
//  3. UPLOAD PHOTO  (called after voice trigger)
// ─────────────────────────────────────────────

exports.uploadPhoto = onRequest(async function (req, res) {
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
      return res.status(404).json({ error: 'No alert found with id ' + alertId });
    }

    const imageUrl = await uploadImageBuffer(req.rawBody, alertId);
    console.log('Image uploaded to Firebase Storage:', imageUrl);

    await alertRef.update({
      imageUrl,
      status: 'complete',
    });

    try {
      await sendAlertToAllContacts({
        imageUrl,
        location: alertSnap.data().location,
        timestamp: new Date().toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' }),
        alertType: 'automatic',
      });
    } catch (alertErr) {
      console.error('Failed to send some WhatsApp alerts:', alertErr.message);
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