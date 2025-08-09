#!/bin/bash

# Quick Blog Demo - Shows Working Translation System
# Perfect for blog screenshots and demonstrations

echo "🚀 AI Translation System - Blog Demo"
echo "====================================="
echo "🎯 Demonstrating: Serverless Translation API with AWS Lambda + API Gateway"
echo

API_BASE_URL="https://rqs7gp9xyf.execute-api.eu-north-1.amazonaws.com/prod"

echo "📡 Step 1: Submit Translation Request"
echo "--------------------------------------"
echo "💬 Text: 'Hello world, how are you today?'"
echo "🌍 Direction: English → Spanish"
echo

# Submit request
RESPONSE=$(curl -s -X POST "$API_BASE_URL/translate/text" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Hello world, how are you today?",
    "sourceLanguage": "en",
    "targetLanguage": "es",
    "waitForResult": false
  }')

echo "📤 API Response:"
echo "$RESPONSE" | jq .
echo

REQUEST_ID=$(echo $RESPONSE | jq -r '.requestId')
echo "🆔 Generated Request ID: $REQUEST_ID"
echo

echo "📊 Step 2: Show System Working"
echo "-------------------------------"
export AWS_DEFAULT_REGION=eu-north-1

echo "📥 Recent translation requests in S3:"
aws s3 ls s3://ai-and-automation/requests/ --recursive | tail -2
echo

echo "✅ Recent completed translations in S3:"
aws s3 ls s3://ai-and-automation/responses/ --recursive | tail -2
echo

echo "🎯 Step 3: Show Actual Translation Result"
echo "-----------------------------------------"
echo "📄 Fetching a completed translation from S3..."

# Get the most recent completed translation
LATEST_RESULT=$(aws s3 ls s3://ai-and-automation/responses/ --recursive | tail -1 | awk '{print $4}')
echo "📁 File: $LATEST_RESULT"
echo

echo "📋 Translation Result:"
aws s3 cp s3://ai-and-automation/$LATEST_RESULT - | jq .
echo

echo "🏗️ Step 4: Architecture Overview"
echo "--------------------------------"
echo "📐 System Components:"
echo "   🌐 API Gateway: Entry point for translation requests"
echo "   ⚡ Lambda (Node.js): Request processing and validation"
echo "   📦 S3 Storage: Request/response persistence"
echo "   🤖 Lambda (Python): AWS Translate integration"
echo "   🔄 Event-driven: S3 triggers translation processing"
echo

echo "🔗 Step 5: API Endpoints"
echo "------------------------"
echo "📍 Base URL: $API_BASE_URL"
echo "   POST /translate/text    - Text translation"
echo "   POST /translate/file    - File translation"
echo "   GET  /translate/status/{id} - Check translation status"
echo

echo "📱 Step 6: Test All Endpoints"
echo "-----------------------------"

# Test file translation
echo "🗂️ Testing file translation..."
FILE_RESPONSE=$(curl -s -X POST "$API_BASE_URL/translate/file" \
  -H "Content-Type: application/json" \
  -d '{
    "fileContent": "{\"welcome\": \"Welcome to our app!\", \"goodbye\": \"See you later!\"}",
    "fileName": "messages.json",
    "sourceLanguage": "en",
    "targetLanguage": "es",
    "waitForResult": false
  }')

echo "📄 File translation response:"
echo "$FILE_RESPONSE" | jq .
echo

# Test status endpoint
echo "🔍 Testing status endpoint..."
STATUS_RESPONSE=$(curl -s "$API_BASE_URL/translate/status/$REQUEST_ID")
echo "📊 Status response:"
echo "$STATUS_RESPONSE" | jq .
echo

echo "✅ Demo Complete - Perfect for Blog!"
echo "===================================="
echo
echo "🎉 Key Points for Your Blog:"
echo "   • ✅ Complete serverless architecture"
echo "   • ✅ Real-time API responses"
echo "   • ✅ Multiple language support"
echo "   • ✅ File and text translation"
echo "   • ✅ Scalable AWS infrastructure"
echo "   • ✅ RESTful API design"
echo
echo "📸 Screenshot-ready endpoints:"
echo "   curl -X POST '$API_BASE_URL/translate/text' -H 'Content-Type: application/json' -d '{\"text\":\"Hello\",\"sourceLanguage\":\"en\",\"targetLanguage\":\"es\",\"waitForResult\":false}'"
echo
echo "🔗 GitHub Repo: Ready for blog integration!"
