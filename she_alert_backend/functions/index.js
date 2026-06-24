require('dotenv').config();

const { onRequest } = require('firebase-functions/v2/https');
const { setGlobalOptions } = require('firebase-functions/v2');
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

const ELEVENLABS_API_KEY = process.env.ELEVENLABS_API_KEY;
const CIRCUITDIGEST_API_KEY = process.env.CIRCUITDIGEST_API_KEY;

// ─────────────────────────────────────────────
//  HELPERS
// ─────────────────────────────────────────────

function detectTrigger(transcript, triggerWord = 'blueberry') {
  return transcript.toLowerCase().includes(triggerWord.toLowerCase());
}

async function transcribeAudio(audioBuffer) {
  const form = new FormData();
  form.append('file', audioBuffer, { filename: 'audio.wav' });
  form.append('model_id', 'scribe_v1');
  form.append('language', 'en');

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
  return 'https://storage.googleapis.com/' + bucket.name + '/' + fileName;
}

async function uploadAudioBuffer(buffer, alertId) {
  const bucket = storage.bucket();
  const fileName = 'alerts/' + alertId + '/audio.wav';
  const file = bucket.file(fileName);

  await file.save(buffer, {
    metadata: {
      contentType: 'audio/wav',
      customTime: new Date().toISOString(),
    },
  });

  await file.makePublic();
  const publicUrl = 'https://storage.googleapis.com/' + bucket.name + '/' + fileName;
  console.log('Audio uploaded to Firebase Storage:', publicUrl);
  return publicUrl;
}

async function getLastKnownLocation(userId) {
  const userDoc = await db.collection('users').doc(userId).get();
  if (!userDoc.exists) return null;
  return userDoc.data().lastKnownLocation || null;
}

async function getContactPhones(userId) {
  const snap = await db
    .collection('users')
    .doc(userId)
    .collection('contacts')
    .orderBy('priority')
    .get();

  const phones = [];
  snap.forEach((doc) => {
    const phone = doc.data().phoneNumber;
    if (phone && phone.trim().length >= 7) {
      phones.push(phone.trim());
    }
  });

  console.log(`Found ${phones.length} contacts for user ${userId}:`, phones);
  return phones;
}

async function sendWhatsAppAlert({ imageUrl, audioUrl, location, timestamp, phoneNumber, alertType }) {
  const mapsLink =
    location
      ? 'https://maps.google.com/?q=' + location.latitude + ',' + location.longitude
      : 'Location unavailable';

  let eventType = '';
  if (alertType === 'manual') {
    eventType = 'SOS Triggered Manually';
  } else {
    const parts = ['SOS Triggered'];
    if (imageUrl) parts.push('Photo: ' + imageUrl);
    if (audioUrl) parts.push('Audio: ' + audioUrl);
    eventType = parts.join(' | ');
  }

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

async function sendAlertToAllContacts({ userId, imageUrl, audioUrl, location, timestamp, alertType }) {
  const contacts = await getContactPhones(userId);
  let successCount = 0;

  if (contacts.length === 0) {
    console.warn(`Found 0 contacts for user ${userId} — no WhatsApp messages sent.`);
    return successCount;
  }

  for (let i = 0; i < contacts.length; i++) {
    try {
      await sendWhatsAppAlert({
        imageUrl,
        audioUrl,
        location,
        timestamp,
        alertType,
        phoneNumber: contacts[i],
      });
      successCount++;
      console.log('WhatsApp alert sent to contact ' + (i + 1) + ' of ' + contacts.length);
    } catch (err) {
      console.error('Failed to alert contact ' + (i + 1) + ':', err.message);
    }

    // Wait 12s before sending to next contact (CircuitDigest rate limit ~9.3–9.4s)
    if (i < contacts.length - 1) {
      console.log('Waiting 12s before next contact to respect rate limit...');
      await new Promise(resolve => setTimeout(resolve, 12000));
    }
  }

  return successCount;
}

// ─────────────────────────────────────────────
//  0. HEARTBEAT  (ESP32 device status ping)
// ─────────────────────────────────────────────

exports.heartbeat = onRequest(
  { timeoutSeconds: 10 },
  async function (req, res) {
    try {
      const userId = req.query.userId;
      if (!userId) return res.status(400).json({ error: 'Missing userId' });

      await db.collection('users').doc(userId).set({
        deviceLastSeen: FieldValue.serverTimestamp(),
        deviceOnline: true,
      }, { merge: true });

      console.log('Heartbeat received from device for userId:', userId);
      return res.json({ success: true });
    } catch (err) {
      console.error('Heartbeat error:', err);
      return res.status(500).json({ error: err.message });
    }
  }
);

// ─────────────────────────────────────────────
//  1. MANUAL ALERT  (SOS hold button in app)
// ─────────────────────────────────────────────

exports.manualAlert = onRequest(
  { timeoutSeconds: 90 },
  async function (req, res) {
    try {
      if (req.method !== 'POST') {
        return res.status(405).json({ error: 'Method not allowed' });
      }

      const { userId, location } = req.body;
      if (!userId) return res.status(400).json({ error: 'Missing userId in request body' });

      console.log('Manual SOS triggered by userId:', userId);

      let resolvedLocation = location || null;
      if (!resolvedLocation) {
        resolvedLocation = await getLastKnownLocation(userId);
        console.log('Fetched last known location:', resolvedLocation);
      }

      const timestamp = new Date().toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' });

      const alertDoc = await db.collection('alerts').add({
        userId,
        type: 'manual',
        triggered: true,
        imageUrl: null,
        audioUrl: null,
        location: resolvedLocation,
        status: 'sent',
        timestamp: FieldValue.serverTimestamp(),
      });

      console.log('Manual alert saved with ID:', alertDoc.id);

      const sent = await sendAlertToAllContacts({
        userId,
        imageUrl: null,
        audioUrl: null,
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
  }
);

// ─────────────────────────────────────────────
//  2. PROCESS AUDIO  (automatic voice trigger)
// ─────────────────────────────────────────────

exports.processAudio = onRequest(
  { timeoutSeconds: 60 },
  async function (req, res) {
    try {
      console.log('Body size:', req.rawBody ? req.rawBody.length : 'no body received');

      if (!req.rawBody || req.rawBody.length === 0) {
        return res.status(400).json({ error: 'No audio data received in request body' });
      }

      const userId = req.query.userId;
      const lat = req.query.lat ? parseFloat(req.query.lat) : null;
      const lng = req.query.lng ? parseFloat(req.query.lng) : null;

      if (!userId) return res.status(400).json({ error: 'Missing userId query param' });

      const transcript = await transcribeAudio(req.rawBody);
      console.log('Transcript:', transcript);

      const triggered = detectTrigger(transcript);

      if (!triggered) {
        return res.json({ transcript, triggered });
      }

      let location = (lat && lng) ? { latitude: lat, longitude: lng } : null;
      if (!location) {
        location = await getLastKnownLocation(userId);
      }

      console.log('Location:', location ? location.latitude + ', ' + location.longitude : 'unavailable');

      const alertDoc = await db.collection('alerts').add({
        userId,
        type: 'automatic',
        transcript,
        triggered,
        imageUrl: null,
        audioUrl: null,
        location,
        status: 'pending_photo',
        timestamp: FieldValue.serverTimestamp(),
      });

      console.log('Automatic alert written with ID:', alertDoc.id);

      // Save audio to Firebase Storage
      let audioUrl = null;
      try {
        audioUrl = await uploadAudioBuffer(req.rawBody, alertDoc.id);
        await alertDoc.update({ audioUrl });
        console.log('Audio URL saved to alert:', audioUrl);
      } catch (audioErr) {
        console.error('Failed to upload audio:', audioErr.message);
      }

      return res.json({
        transcript,
        triggered,
        imageUrl: null,
        audioUrl,
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
  }
);

// ─────────────────────────────────────────────
//  3. UPLOAD PHOTO  (called after voice trigger)
// ─────────────────────────────────────────────

exports.uploadPhoto = onRequest(
  { timeoutSeconds: 90 },
  async function (req, res) {
    try {
      const alertId = req.query.alertId;
      if (!alertId) return res.status(400).json({ error: 'Missing alertId query param' });

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

      await alertRef.update({ imageUrl, status: 'complete' });

      const audioUrl = alertSnap.data().audioUrl || null;

      try {
        const alertData = alertSnap.data();
        await sendAlertToAllContacts({
          userId: alertData.userId,
          imageUrl,
          audioUrl,
          location: alertData.location,
          timestamp: new Date().toLocaleString('en-IN', { timeZone: 'Asia/Kolkata' }),
          alertType: 'automatic',
        });
      } catch (alertErr) {
        console.error('Failed to send some WhatsApp alerts:', alertErr.message);
      }

      return res.json({ alertId, imageUrl, audioUrl, status: 'complete' });
    } catch (err) {
      console.error('uploadPhoto error:', err);
      return res.status(500).json({
        error: err.message || 'Unknown error',
        details: JSON.stringify(err, Object.getOwnPropertyNames(err)),
      });
    }
  }
);