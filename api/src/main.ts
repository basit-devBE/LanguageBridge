import {Request, Response} from 'express';
import dotenv from 'dotenv';
import { uploadFile } from './aws';


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