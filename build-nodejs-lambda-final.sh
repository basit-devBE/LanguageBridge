#!/bin/bash

# Build script to compile Node.js API for Lambda deployment

echo "🔨 Building Node.js API for Lambda deployment..."

# Use a completely separate build directory
BUILD_DIR="/tmp/nodejs-lambda-build-$(date +%s)"
TARGET_ZIP="/tmp/nodejs-api-lambda-$(date +%s).zip"

# Clean up any existing build directory
rm -rf $BUILD_DIR
mkdir -p $BUILD_DIR

echo "📂 Copying source files to $BUILD_DIR..."
# Copy the Node.js API source files
cp -r /home/basit/Desktop/github_projects/AI_Automation/api/src $BUILD_DIR/
cp /home/basit/Desktop/github_projects/AI_Automation/api/package.json $BUILD_DIR/
cp /home/basit/Desktop/github_projects/AI_Automation/api/tsconfig.json $BUILD_DIR/
cp /home/basit/Desktop/github_projects/AI_Automation/lambda/nodejs-api-handler.js $BUILD_DIR/

# Navigate to build directory
cd $BUILD_DIR || exit 1

echo "📦 Installing dependencies..."
# Install dependencies (production only)
npm install --production --silent

echo "🔧 Installing TypeScript compiler..."
# Install TypeScript compiler
npm install typescript @types/node --save-dev --silent

echo "⚙️ Compiling TypeScript..."
# Compile TypeScript
npx tsc --outDir compiled

echo "🔄 Creating Lambda handler..."
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

echo "📦 Creating deployment package at $TARGET_ZIP..."
# Create deployment package in temp location
zip -r $TARGET_ZIP . -x "*.ts" "tsconfig.json" "src/*" "node_modules/.bin/*" > /dev/null

echo "📋 Moving package to infrastructure directory..."
# Remove any existing package in the infrastructure directory
rm -f /home/basit/Desktop/github_projects/AI_Automation/infrastructure/nodejs-api-lambda.zip

# Move the new package to the infrastructure directory
mv $TARGET_ZIP /home/basit/Desktop/github_projects/AI_Automation/infrastructure/nodejs-api-lambda.zip

# Clean up build directory
rm -rf $BUILD_DIR

echo "✅ Build complete! Package created at:"
echo "   /home/basit/Desktop/github_projects/AI_Automation/infrastructure/nodejs-api-lambda.zip"
echo ""

# Verify package contents
PACKAGE_SIZE=$(ls -lh /home/basit/Desktop/github_projects/AI_Automation/infrastructure/nodejs-api-lambda.zip | awk '{print $5}')
echo "📋 Package size: $PACKAGE_SIZE"
echo "📋 Package verification:"
unzip -l /home/basit/Desktop/github_projects/AI_Automation/infrastructure/nodejs-api-lambda.zip | head -10

echo ""
echo "🚀 Ready for deployment with Terraform!"
