require('dotenv').config();
const functions = require('firebase-functions');
const fetch = require('node-fetch');
const FormData = require('form-data');
const cloudinary = require('cloudinary').v2;

const ELEVENLABS_API_KEY = process.env.ELEVENLABS_API_KEY;

cloudinary.config({
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET,
});

console.log('Cloudinary config check:', {
  cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
  api_key: process.env.CLOUDINARY_API_KEY,
  api_secret: process.env.CLOUDINARY_API_SECRET ? 'SET' : 'MISSING',
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

// NEW: uploads an image to Cloudinary and returns its public URL
async function uploadImage(filePath) {
  const result = await cloudinary.uploader.upload(filePath, {
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

    // --- Image URL gets added here, only when triggered ---
    let imageUrl = null;
    try {
      imageUrl = await uploadImage('C:\\Users\\THIRUMALAI\\Pictures\\Camera Roll\\nature.jpg');
      console.log('Image uploaded:', imageUrl);
    } catch (uploadErr) {
      console.error('Cloudinary upload error:', uploadErr);
      // don't crash the whole request just because image upload failed
      return res.json({ transcript, triggered, imageUrl: null, imageError: uploadErr.message });
    }

    return res.json({ transcript, triggered, imageUrl });
  } catch (err) {
    console.error('processAudio error:', err);
    return res.status(500).json({
      error: err.message || 'Unknown error',
      details: JSON.stringify(err, Object.getOwnPropertyNames(err)),
    });
  }
});