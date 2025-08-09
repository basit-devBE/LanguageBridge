import dotenv from 'dotenv'
import path, { resolve } from 'path'
import fs from 'fs'
import AWS from 'aws-sdk'

dotenv.config()

// Check if running in Lambda environment
const isLambda = !!process.env.LAMBDA_RUNTIME_DIR;

if (isLambda) {
    // In Lambda, use IAM role credentials automatically
    console.log('Running in Lambda environment, using IAM role credentials');
    
    // Only validate required S3 bucket name
    if (!process.env.AWS_S3_BUCKET_NAME) {
        throw new Error('Missing required environment variable: AWS_S3_BUCKET_NAME');
    }
    
    // Lambda automatically sets AWS_REGION, but we can override it
    AWS.config.update({
        region: process.env.AWS_REGION || 'eu-north-1'
    });
} else {
    // In local development, validate explicit credentials
    const requiredEnvVars = {
        AWS_ACCESS_KEY: process.env.AWS_ACCESS_KEY,
        AWS_SECRET_ACCESS_KEY: process.env.AWS_SECRET_ACCESS_KEY,
        AWS_REGION: process.env.AWS_REGION,
        AWS_S3_BUCKET_NAME: process.env.AWS_S3_BUCKET_NAME
    };

    console.log('Environment variables check:');
    for (const [key, value] of Object.entries(requiredEnvVars)) {
        console.log(`${key}: ${value ? '✓ Set' : '✗ Missing'}`);
        if (!value) {
            throw new Error(`Missing required environment variable: ${key}`);
        }
    }

    AWS.config.update({
        accessKeyId: process.env.AWS_ACCESS_KEY,
        secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY,
        region: process.env.AWS_REGION
    });
}

const s3 = new AWS.S3();

export const uploadFile = async (filename: string): Promise<AWS.S3.ManagedUpload.SendData> => {
    console.log(`\n=== Starting upload process for: ${filename} ===`);
    
    try {
        const filePath = path.resolve(process.cwd(), 'uploads', filename);
        console.log(`Resolved file path: ${filePath}`);

        if (!fs.existsSync(filePath)) {
            const error = `File does not exist at path: ${filePath}`;
            console.error(error);
            throw new Error(error);
        }

        const fileContent = fs.readFileSync(filePath);
        console.log('File content read successfully, size:', fileContent.length, 'bytes');

        // Test S3 connection first
        console.log('Testing S3 connection...');
        try {
            await s3.headBucket({ Bucket: process.env.AWS_S3_BUCKET_NAME! }).promise();
            console.log('✓ S3 bucket access confirmed');
        } catch (bucketError) {
            console.error('✗ S3 bucket access failed:', bucketError);
            const errorMessage = (bucketError && typeof bucketError === 'object' && 'message' in bucketError)
                ? (bucketError as { message: string }).message
                : String(bucketError);
            throw new Error(`S3 bucket access failed: ${errorMessage}`);
        }

        const params: AWS.S3.PutObjectRequest = {
            Bucket: process.env.AWS_S3_BUCKET_NAME!,
            Key: filename,
            Body: fileContent,
            ContentType: 'application/octet-stream'
        };

        console.log("Upload parameters:", {
            Bucket: params.Bucket,
            Key: params.Key,
            BodySize: fileContent.length,
            ContentType: params.ContentType
        });

        console.log("Starting S3 upload...");
        
        // Add upload progress tracking
        const upload = s3.upload(params);
        
        upload.on('httpUploadProgress', (progress) => {
            console.log(`Upload progress: ${Math.round((progress.loaded / progress.total) * 100)}%`);
        });

        const result = await upload.promise();
        console.log('✓ File uploaded successfully:', {
            Location: result.Location,
            ETag: result.ETag,
            Key: result.Key
        });
        
        console.log(`=== Upload completed successfully ===\n`);
        return result;

    } catch (error) {
        console.error('✗ Error in uploadFile:');
        if (error instanceof Error) {
            console.error('Error name:', error.name);
            console.error('Error message:', error.message);
            // Some AWS errors may not extend Error, so check for code property
            if ('code' in error) {
                console.error('Error code:', (error as any).code);
            }
            console.error('Error stack:', error.stack);
        } else if (typeof error === 'object' && error !== null) {
            console.error('Error name:', (error as any).name);
            console.error('Error message:', (error as any).message);
            console.error('Error code:', (error as any).code);
            console.error('Error stack:', (error as any).stack);
        } else {
            console.error('Unknown error type:', error);
        }
        
        // Additional AWS-specific error handling
        if (typeof error === 'object' && error !== null && 'code' in error) {
            switch ((error as any).code) {
                case 'NoSuchBucket':
                    console.error('The specified bucket does not exist');
                    break;
                case 'AccessDenied':
                    console.error('Access denied - check your AWS credentials and bucket permissions');
                    break;
                case 'SignatureDoesNotMatch':
                    console.error('AWS signature mismatch - check your secret access key');
                    break;
                case 'InvalidAccessKeyId':
                    console.error('Invalid AWS access key ID');
                    break;
                default:
                    console.error('AWS error code:', (error as any).code);
            }
        }
        
        console.log(`=== Upload failed ===\n`);
        throw error;
    }
}

// NEW: Add translation-specific upload function
export const uploadTranslationRequest = async (
    translationData: any,
    requestId: string
): Promise<AWS.S3.ManagedUpload.SendData> => {
    console.log(`\n=== Starting translation request upload: ${requestId} ===`);
    
    try {
        const params: AWS.S3.PutObjectRequest = {
            Bucket: process.env.AWS_S3_BUCKET_NAME!,
            Key: `requests/${requestId}_${Date.now()}.json`,
            Body: JSON.stringify(translationData, null, 2),
            ContentType: 'application/json',
            Metadata: {
                'request-type': 'translation',
                'request-id': requestId
            }
        };

        console.log("Translation upload parameters:", {
            Bucket: params.Bucket,
            Key: params.Key,
            ContentType: params.ContentType
        });

        const result = await s3.upload(params).promise();
        console.log('✓ Translation request uploaded successfully:', result.Key);
        
        return result;

    } catch (error) {
        console.error('✗ Error uploading translation request:', error);
        throw error;
    }
}

// NEW: Get translation result
export const getTranslationResult = async (requestId: string): Promise<any | null> => {
    try {
        console.log(`Checking for translation result: ${requestId}`);
        
        const listParams = {
            Bucket: process.env.AWS_S3_BUCKET_NAME!,
            Prefix: `responses/${requestId}`
        };

        const objects = await s3.listObjectsV2(listParams).promise();
        
        if (!objects.Contents || objects.Contents.length === 0) {
            console.log('No translation result found yet');
            return null;
        }

        // Get the most recent result
        const latestObject = objects.Contents.sort((a, b) => 
            (b.LastModified?.getTime() || 0) - (a.LastModified?.getTime() || 0)
        )[0];

        const getParams = {
            Bucket: process.env.AWS_S3_BUCKET_NAME!,
            Key: latestObject.Key!
        };

        const result = await s3.getObject(getParams).promise();
        const translationResult = JSON.parse(result.Body?.toString() || '{}');
        
        console.log('✓ Translation result found:', translationResult.status);
        return translationResult;

    } catch (error) {
        console.error('✗ Error getting translation result:', error);
        return null;
    }
}

// Add a test function to verify AWS connection
export const testAWSConnection = async (): Promise<boolean> => {
    try {
        console.log('Testing AWS S3 connection...');
        const result = await s3.listBuckets().promise();
        console.log('✓ AWS connection successful. Available buckets:', result.Buckets?.map(b => b.Name));
        return true;
    } catch (error) {
        if (error instanceof Error) {
            console.error('✗ AWS connection failed:', error.message);
        } else {
            console.error('✗ AWS connection failed:', error);
        }
        return false;
    }
}