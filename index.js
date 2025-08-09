// AWS Lambda handler that adapts your Node.js Express API
const path = require('path');
const fs = requi        // Route to appropriate handler
        if (requestPath === '/translate/text' && method === 'POST') {
            console.log('Calling translateTextHandler...');
            await translateTextHandler(req, res);
        } else if (requestPath === '/translate/file' && method === 'POST') {
            console.log('Calling translateFileHandler...');
            await handleFileUpload(req);  // Properly await file upload
            await translateFileHandler(req, res);
        } else if (requestPath.startsWith('/translate/status/') && method === 'GET') {
            console.log('Calling getTranslationStatusHandler...');
            await getTranslationStatusHandler(req, res);
        } else {
            console.log('Route not found:', method, requestPath);
            res.status(404).json({ error: 'Not Found', path: requestPath, method: method });
        }mport your compiled handlers
const { translateTextHandler, translateFileHandler, getTranslationStatusHandler } = require('./compiled/src/main');

// Mock Express Request/Response objects for Lambda
class MockRequest {
    constructor(event) {
        this.body = event.body ? JSON.parse(event.body) : {};
        this.params = event.pathParameters || {};
        this.query = event.queryStringParameters || {};
        this.headers = event.headers || {};
        this.method = event.httpMethod;
        this.path = event.path;
        
        // For file upload simulation
        this.file = null;
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

// File upload handler for Lambda
async function handleFileUpload(req) {
    if (req.body.fileContent && req.body.fileName) {
        const tempDir = '/tmp';
        const filename = `upload_${Date.now()}.json`;
        const filePath = path.join(tempDir, filename);
        
        try {
            // Ensure the temp directory exists
            if (!fs.existsSync(tempDir)) {
                fs.mkdirSync(tempDir, { recursive: true });
            }
            
            // Write file content to /tmp
            fs.writeFileSync(filePath, req.body.fileContent);
            
            req.file = {
                filename: filename,
                originalname: req.body.fileName || 'upload.json',
                mimetype: 'application/json',
                path: filePath
            };
            
            console.log('File uploaded to:', filePath);
            console.log('File exists:', fs.existsSync(filePath));
        } catch (error) {
            console.error('Error handling file upload:', error);
            throw error;
        }
    }
}

// Main Lambda handler
exports.handler = async (event, context) => {
    console.log('Received event:', JSON.stringify(event, null, 2));
    
    try {
        const req = new MockRequest(event);
        const res = new MockResponse();
        
        const requestPath = event.path;
        const method = event.httpMethod;
        
        console.log(`Processing ${method} ${requestPath}`);
        console.log('Request body:', JSON.stringify(req.body, null, 2));
        
        // Route to appropriate handler
        if (requestPath === '/translate/text' && method === 'POST') {
            console.log('Calling translateTextHandler...');
            await translateTextHandler(req, res);
        } else if (requestPath === '/translate/file' && method === 'POST') {
            console.log('Calling translateFileHandler...');
            await handleFileUpload(req);
            await translateFileHandler(req, res);
        } else if (requestPath.startsWith('/translate/status/') && method === 'GET') {
            console.log('Calling getTranslationStatusHandler...');
            await getTranslationStatusHandler(req, res);
        } else {
            console.log('Route not found:', method, requestPath);
            res.status(404).json({ error: 'Not Found', path: requestPath, method: method });
        }
        
        console.log('Handler completed. Response:', JSON.stringify(res.toAPIGatewayResponse(), null, 2));
        return res.toAPIGatewayResponse();
        
    } catch (error) {
        console.error('Lambda handler error:', error);
        console.error('Error stack:', error.stack);
        return {
            statusCode: 500,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({
                error: 'Internal Server Error',
                message: error.message,
                stack: error.stack
            })
        };
    }
};
