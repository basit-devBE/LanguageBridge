#!/bin/bash

# Build script to compile Node.js API for Lambda deployment

echo "🔨 Building Node.js API for Lambda deployment..."

# Create build directory
BUILD_DIR="/tmp/nodejs-lambda-build"
rm -rf $BUILD_DIR
mkdir -p $BUILD_DIR

# Copy the Node.js API source files
echo "📂 Copying source files..."
cp -r /home/basit/Desktop/github_projects/AI_Automation/api/src $BUILD_DIR/
cp /home/basit/Desktop/github_projects/AI_Automation/api/package.json $BUILD_DIR/
cp /home/basit/Desktop/github_projects/AI_Automation/api/tsconfig.json $BUILD_DIR/
cp /home/basit/Desktop/github_projects/AI_Automation/lambda/nodejs-api-handler.js $BUILD_DIR/

# Navigate to build directory
cd $BUILD_DIR || exit 1

# Install dependencies (production only)
echo "📦 Installing dependencies..."
npm install --production

# Install TypeScript compiler
npm install typescript @types/node --save-dev

# Compile TypeScript
echo "🔧 Compiling TypeScript..."
npx tsc --outDir compiled

# Update the main handler to adjust paths for Lambda environment
echo "🔄 Updating handler for Lambda environment..."

# Create the final Lambda handler
cat > index.js << 'EOF'
// AWS Lambda handler that adapts your Node.js Express API
const path = require('path');
const fs = require('fs');

// Import your compiled handlers
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
function handleFileUpload(req) {
    if (req.body.fileContent && req.body.fileName) {
        const tempDir = '/tmp';
        const filename = `upload_${Date.now()}.json`;
        const filePath = path.join(tempDir, filename);
        
        // Write file content to /tmp
        fs.writeFileSync(filePath, req.body.fileContent);
        
        req.file = {
            filename: filename,
            originalname: req.body.fileName || 'upload.json',
            mimetype: 'application/json',
            path: filePath
        };
        
        // Override the uploads directory for Lambda
        process.cwd = () => tempDir;
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
        
        // Route to appropriate handler
        if (requestPath === '/translate/text' && method === 'POST') {
            await translateTextHandler(req, res);
        } else if (requestPath === '/translate/file' && method === 'POST') {
            handleFileUpload(req);
            await translateFileHandler(req, res);
        } else if (requestPath.startsWith('/translate/status/') && method === 'GET') {
            await getTranslationStatusHandler(req, res);
        } else {
            res.status(404).json({ error: 'Not Found', path: requestPath, method: method });
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
                message: error.message,
                stack: error.stack
            })
        };
    }
};
EOF

# Create deployment package
echo "📦 Creating deployment package..."
TARGET_ZIP="/home/basit/Desktop/github_projects/AI_Automation/infrastructure/nodejs-api-lambda.zip"
rm -f "$TARGET_ZIP"
zip -r /tmp/nodejs-api-lambda.zip . -x "*.ts" "tsconfig.json" "src/*" "node_modules/.bin/*" "nodejs-api-handler.js"
mv /tmp/nodejs-api-lambda.zip "$TARGET_ZIP"

echo "✅ Build complete! Package created at:"
echo "   /home/basit/Desktop/github_projects/AI_Automation/infrastructure/nodejs-api-lambda.zip"
echo ""
echo "📋 Package contents:"
echo "   - Compiled JavaScript from your TypeScript API"
echo "   - Node.js dependencies"
echo "   - Lambda adapter for API Gateway integration"
echo ""
echo "🚀 Ready for deployment with Terraform!"
