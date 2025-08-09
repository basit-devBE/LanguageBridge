import {Request, Response} from 'express';
import dotenv from 'dotenv';
import { uploadFile, uploadTranslationRequest, getTranslationResult } from './aws';
import { v4 as uuidv4 } from 'uuid';
import fs from 'fs';
import path from 'path';


export const uploadFileHandler = async (req:Request, res:Response)=>{
    const file = req.file;
    if(!file){
        return res.status(400).json({error: 'No file uploaded'});
    }

    try{
        const result = await uploadFile(file.filename);
        return res.status(200).json({
            message: 'File uploaded successfully',
            data: result
        });
    }catch(error){
        console.error('Error uploading file:', error);
        return res.status(500).json({
            error: 'Failed to upload file',
            details: error instanceof Error ? error.message : 'Unknown error'
        });
    }
}

// UPDATED: Text translation handler with wait functionality
export const translateTextHandler = async (req: Request, res: Response) => {
    try {
        const { text, sourceLanguage = 'auto', targetLanguage = 'en', waitForResult = true } = req.body;
        
        if (!text) {
            return res.status(400).json({ error: 'Text is required' });
        }

        const requestId = uuidv4();
        const translationRequest = {
            request_id: requestId,
            text: text,
            source_language: sourceLanguage,
            target_language: targetLanguage,
            timestamp: new Date().toISOString(),
            type: 'text_translation'
        };

        // Upload request to S3
        await uploadTranslationRequest(translationRequest, requestId);
        console.log(`Translation request uploaded for ID: ${requestId}`);

        // If waitForResult is false, return immediately
        if (!waitForResult) {
            return res.status(202).json({
                message: 'Translation request submitted successfully',
                requestId: requestId,
                status: 'processing'
            });
        }

        // Wait for translation to complete
        console.log('Waiting for translation to complete...');
        const result = await waitForTranslationResult(requestId, 30); // 30 second timeout

        if (result) {
            return res.status(200).json({
                message: 'Translation completed successfully',
                requestId: requestId,
                status: 'completed',
                result: result
            });
        } else {
            return res.status(202).json({
                message: 'Translation is taking longer than expected',
                requestId: requestId,
                status: 'processing',
                note: 'Check status endpoint for updates'
            });
        }

    } catch (error) {
        console.error('Error processing translation request:', error);
        return res.status(500).json({
            error: 'Failed to process translation request',
            details: error instanceof Error ? error.message : 'Unknown error'
        });
    }
}

// UPDATED: File translation handler with wait functionality
export const translateFileHandler = async (req: Request, res: Response) => {
    const file = req.file;
    
    if (!file) {
        return res.status(400).json({ error: 'No file uploaded' });
    }

    try {
        const { sourceLanguage = 'auto', targetLanguage = 'en', waitForResult = true } = req.body;
        
        // Read file content - use the direct file path from the upload
        const filePath = file.path || path.resolve(process.cwd(), 'uploads', file.filename);
        let textContent = '';

        console.log(`Reading file from: ${filePath}`);
        console.log(`File exists: ${fs.existsSync(filePath)}`);

        if (file.mimetype === 'application/json') {
            const fileContent = JSON.parse(fs.readFileSync(filePath, 'utf-8'));
            textContent = fileContent.text || JSON.stringify(fileContent);
        } else {
            textContent = fs.readFileSync(filePath, 'utf-8');
        }

        const requestId = uuidv4();
        const translationRequest = {
            request_id: requestId,
            text: textContent,
            source_language: sourceLanguage,
            target_language: targetLanguage,
            timestamp: new Date().toISOString(),
            type: 'file_translation',
            original_filename: file.originalname
        };

        // Upload request to S3
        await uploadTranslationRequest(translationRequest, requestId);
        console.log(`File translation request uploaded for ID: ${requestId}`);

        // Clean up local file
        fs.unlinkSync(filePath);

        // If waitForResult is false, return immediately
        if (!waitForResult) {
            return res.status(202).json({
                message: 'File translation request submitted successfully',
                requestId: requestId,
                status: 'processing',
                originalFilename: file.originalname
            });
        }

        // Wait for translation to complete
        console.log('Waiting for file translation to complete...');
        const result = await waitForTranslationResult(requestId, 30);

        if (result) {
            return res.status(200).json({
                message: 'File translation completed successfully',
                requestId: requestId,
                status: 'completed',
                originalFilename: file.originalname,
                result: result
            });
        } else {
            return res.status(202).json({
                message: 'File translation is taking longer than expected',
                requestId: requestId,
                status: 'processing',
                originalFilename: file.originalname,
                note: 'Check status endpoint for updates'
            });
        }

    } catch (error) {
        console.error('Error processing file translation:', error);
        return res.status(500).json({
            error: 'Failed to process file translation',
            details: error instanceof Error ? error.message : 'Unknown error'
        });
    }
}

// NEW: Get translation status
export const getTranslationStatusHandler = async (req: Request, res: Response) => {
    try {
        const { requestId } = req.params;
        
        if (!requestId) {
            return res.status(400).json({ error: 'Request ID is required' });
        }

        const result = await getTranslationResult(requestId);

        if (!result) {
            return res.status(202).json({
                message: 'Translation still processing',
                requestId: requestId,
                status: 'processing'
            });
        }

        return res.status(200).json({
            message: 'Translation completed',
            requestId: requestId,
            status: 'completed',
            result: result
        });

    } catch (error) {
        console.error('Error getting translation status:', error);
        return res.status(500).json({
            error: 'Failed to get translation status',
            details: error instanceof Error ? error.message : 'Unknown error'
        });
    }
}

// NEW: Helper function to wait for translation result
async function waitForTranslationResult(requestId: string, timeoutSeconds: number = 30): Promise<any | null> {
    const startTime = Date.now();
    const timeoutMs = timeoutSeconds * 1000;
    
    console.log(`Waiting for translation result for request ${requestId} (timeout: ${timeoutSeconds}s)`);
    
    while (Date.now() - startTime < timeoutMs) {
        try {
            const result = await getTranslationResult(requestId);
            
            if (result) {
                console.log(`✓ Translation completed for request ${requestId}`);
                return result;
            }
            
            // Wait 2 seconds before checking again
            await new Promise(resolve => setTimeout(resolve, 2000));
            console.log(`Still waiting for ${requestId}... (${Math.round((Date.now() - startTime) / 1000)}s elapsed)`);
            
        } catch (error) {
            console.error('Error checking translation result:', error);
            // Continue waiting despite errors
            await new Promise(resolve => setTimeout(resolve, 2000));
        }
    }
    
    console.log(`⚠️ Translation timeout for request ${requestId} after ${timeoutSeconds} seconds`);
    return null;
}