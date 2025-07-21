import express from 'express';
import {Request, Response} from 'express';
import dotenv from 'dotenv';
import router from './src/routes';
import {upload} from './src/multer';
import { uploadFileHandler } from './src/main';

dotenv.config();

const app = express();

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Routes
app.get('/', (req: Request, res: Response) => {
  res.send('Hello, World!');
});

// Mount router with base path
app.use('/api', router);

// Error handling middleware
app.use((err: Error, req: Request, res: Response, next: Function) => {
  console.error(err.stack);
  res.status(500).send('Something broke!');
});

// Start server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server is running on http://localhost:${PORT}`);
  console.log('Available routes:');
  console.log('GET /');
  console.log('GET /api/test');
  console.log('POST /api/upload');
});