// AWS Lambda handler that adapts your Node.js Express API
// This allows your existing TypeScript code to run in Lambda

const { translateTextHandler, translateFileHandler, getTranslationStatusHandler } = require('./compiled/main');

// Mock Express Request/Response objects for Lambda
class MockRequest {
    constructor(event) {
        this.body = event.body ? JSON.parse(event.body) : {};
        this.params = event.pathParameters || {};
        this.query = event.queryStringParameters || {};
        this.headers = event.headers || {};
        this.method = event.httpMethod;
        this.path = event.path;
        
        // For file upload simulation (if needed)
        this.file = null;
        if (this.body.fileContent && this.body.fileName) {
            this.file = {
                filename: this.body.fileName,
                originalname: this.body.fileName,
                mimetype: 'application/json',
                buffer: Buffer.from(this.body.fileContent)
            };
        }
    }
}

class MockResponse {
    constructor() {
        this.statusCode = 200;
        this.responseBody = {};
        this.headers = {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Allow-Methods': 'GET, POST, OPTIONS'
        };
    }

    status(code) {
        this.statusCode = code;
        return this;
    }

    json(body) {
        this.responseBody = body;
        return this;
    }

    send(body) {
        this.responseBody = body;
        return this;
    }

    toAPIGatewayResponse() {
        return {
            statusCode: this.statusCode,
            headers: this.headers,
            body: JSON.stringify(this.responseBody)
        };
    }
}

// Main Lambda handler
exports.handler = async (event, context) => {
    console.log('Received event:', JSON.stringify(event, null, 2));
    
    try {
        const req = new MockRequest(event);
        const res = new MockResponse();
        
        const path = event.path;
        const method = event.httpMethod;
        
        // Route to appropriate handler based on path and method
        if (path === '/translate/text' && method === 'POST') {
            await translateTextHandler(req, res);
        } else if (path === '/translate/file' && method === 'POST') {
            // For file translation, we need to handle the fileContent differently
            if (req.body.fileContent) {
                // Create a mock file object for your existing handler
                req.file = {
                    filename: `temp_${Date.now()}.json`,
                    originalname: req.body.fileName || 'upload.json',
                    mimetype: 'application/json'
                };
                
                // Write the file content to a temporary location
                const fs = require('fs');
                const path = require('path');
                const tempDir = '/tmp';
                const tempFilePath = path.join(tempDir, req.file.filename);
                
                fs.writeFileSync(tempFilePath, req.body.fileContent);
                
                // Update the handler to use /tmp instead of uploads
                process.env.TEMP_UPLOAD_DIR = tempDir;
            }
            
            await translateFileHandler(req, res);
        } else if (path.startsWith('/translate/status/') && method === 'GET') {
            await getTranslationStatusHandler(req, res);
        } else {
            res.status(404).json({ error: 'Not Found' });
        }
        
        return res.toAPIGatewayResponse();
        
    } catch (error) {
        console.error('Lambda handler error:', error);
        return {
            statusCode: 500,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({
                error: 'Internal Server Error',
                message: error.message
            })
        };
    }
};
