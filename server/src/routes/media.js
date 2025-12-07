const express = require('express');
const multer = require('multer');
const path = require('path');
const { v4: uuidv4 } = require('uuid');
const sharp = require('sharp');
const fs = require('fs').promises;

const router = express.Router();

const BASE_URL = process.env.BASE_URL || 'http://localhost:3000';
const MAX_FILE_SIZE = (parseInt(process.env.MAX_FILE_SIZE_MB) || 10) * 1024 * 1024;

// Configure multer for file uploads
const storage = multer.memoryStorage();

const upload = multer({
  storage,
  limits: {
    fileSize: MAX_FILE_SIZE
  },
  fileFilter: (req, file, cb) => {
    const allowedTypes = ['image/jpeg', 'image/png', 'image/gif', 'image/webp', 'video/mp4', 'video/quicktime'];
    if (allowedTypes.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('Invalid file type. Allowed: JPEG, PNG, GIF, WebP, MP4, MOV'));
    }
  }
});

// Upload image
router.post('/upload/image', upload.single('image'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No image file provided' });
    }

    const { chatId, messageId } = req.body;
    if (!chatId || !messageId) {
      return res.status(400).json({ error: 'chatId and messageId are required' });
    }

    const filename = `${messageId}.jpg`;
    const chatDir = path.join(__dirname, '../../uploads/images', chatId);

    // Create chat directory if not exists
    await fs.mkdir(chatDir, { recursive: true });

    const filepath = path.join(chatDir, filename);

    // Process and compress image with sharp
    await sharp(req.file.buffer)
      .resize(1920, 1920, {
        fit: 'inside',
        withoutEnlargement: true
      })
      .jpeg({ quality: 80 })
      .toFile(filepath);

    const imageUrl = `${BASE_URL}/uploads/images/${chatId}/${filename}`;

    console.log(`📷 Image uploaded: ${imageUrl}`);

    res.json({
      success: true,
      url: imageUrl,
      messageId,
      chatId
    });
  } catch (error) {
    console.error('Upload error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Upload video
router.post('/upload/video', upload.single('video'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'No video file provided' });
    }

    const { chatId, messageId } = req.body;
    if (!chatId || !messageId) {
      return res.status(400).json({ error: 'chatId and messageId are required' });
    }

    const ext = req.file.mimetype === 'video/quicktime' ? 'mov' : 'mp4';
    const filename = `${messageId}.${ext}`;
    const chatDir = path.join(__dirname, '../../uploads/videos', chatId);

    await fs.mkdir(chatDir, { recursive: true });

    const filepath = path.join(chatDir, filename);
    await fs.writeFile(filepath, req.file.buffer);

    const videoUrl = `${BASE_URL}/uploads/videos/${chatId}/${filename}`;

    console.log(`🎬 Video uploaded: ${videoUrl}`);

    res.json({
      success: true,
      url: videoUrl,
      messageId,
      chatId
    });
  } catch (error) {
    console.error('Upload error:', error);
    res.status(500).json({ error: error.message });
  }
});

// Delete media
router.delete('/:chatId/:filename', async (req, res) => {
  try {
    const { chatId, filename } = req.params;

    // Try images first, then videos
    const imagePath = path.join(__dirname, '../../uploads/images', chatId, filename);
    const videoPath = path.join(__dirname, '../../uploads/videos', chatId, filename);

    try {
      await fs.unlink(imagePath);
      return res.json({ success: true, deleted: 'image' });
    } catch {
      try {
        await fs.unlink(videoPath);
        return res.json({ success: true, deleted: 'video' });
      } catch {
        return res.status(404).json({ error: 'File not found' });
      }
    }
  } catch (error) {
    console.error('Delete error:', error);
    res.status(500).json({ error: error.message });
  }
});

module.exports = router;
