import express from 'express';
import {upload} from './multer';
import {uploadFileHandler} from './main';

const router = express.Router();

console.log('Setting up routes...'); // Add debugging

router.get('/test', (req, res) => {
    console.log('Test route hit!'); // Add debugging
    res.json({ message: 'Router is working!' });
});

router.post('/upload', upload.single('file'), uploadFileHandler);

console.log('Routes setup complete'); // Add debugging

export default router;