import express from 'express';
import {upload} from './multer';
import {uploadFileHandler, translateTextHandler, getTranslationStatusHandler, translateFileHandler} from './main';

const router = express.Router();

console.log('Setting up routes...'); // Add debugging

router.get('/test', (req, res) => {
    console.log('Test route hit!'); // Add debugging
    res.json({ message: 'Router is working!' });
});

// Existing file upload
router.post('/upload', upload.single('file'), uploadFileHandler);

// NEW: Translation routes
router.post('/translate/text', translateTextHandler);
router.post('/translate/file', upload.single('file'), translateFileHandler);
router.get('/translate/status/:requestId', getTranslationStatusHandler);

console.log('Routes setup complete'); // Add debugging

export default router;