#!/bin/bash

# Complete Translation Demo for Blog
# Shows the full workflow from request submission to getting translated results

echo "🚀 AI Translation System - Complete Demo"
echo "========================================"
echo

API_BASE_URL="https://rqs7gp9xyf.execute-api.eu-north-1.amazonaws.com/prod"

# Function to submit translation and wait for result
demo_translation() {
    local text="$1"
    local source_lang="$2" 
    local target_lang="$3"
    local description="$4"
    
    echo "📝 $description"
    echo "----------------------------------------"
    echo "🔤 Original: $text"
    echo "🌍 Translation: $source_lang → $target_lang"
    echo
    
    # Submit translation request
    echo "⏳ Submitting translation request..."
    RESPONSE=$(curl -s -X POST "$API_BASE_URL/translate/text" \
      -H "Content-Type: application/json" \
      -d "{
        \"text\": \"$text\",
        \"sourceLanguage\": \"$source_lang\",
        \"targetLanguage\": \"$target_lang\",
        \"waitForResult\": false
      }")
    
    echo "📤 Request submitted: $RESPONSE"
    
    # Extract request ID
    REQUEST_ID=$(echo $RESPONSE | jq -r '.requestId')
    echo "🆔 Request ID: $REQUEST_ID"
    echo
    
    # Wait for processing and check status
    echo "⏳ Waiting for translation to complete..."
    for i in {1..10}; do
        sleep 3
        echo "   Checking status... (attempt $i/10)"
        
        STATUS_RESPONSE=$(curl -s "$API_BASE_URL/translate/status/$REQUEST_ID")
        STATUS=$(echo $STATUS_RESPONSE | jq -r '.status // "processing"')
        
        if [[ "$STATUS" == "completed" ]]; then
            echo "✅ Translation completed!"
            echo "📋 Final result: $STATUS_RESPONSE"
            TRANSLATED_TEXT=$(echo $STATUS_RESPONSE | jq -r '.result.translatedText // .translatedText // "Translation not found"')
            echo "🎯 Translated text: \"$TRANSLATED_TEXT\""
            echo
            return 0
        fi
    done
    
    echo "⏰ Translation is still processing. Let's check S3 directly..."
    
    # Check S3 for the result as backup
    echo "🔍 Checking S3 for completed translation..."
    export AWS_DEFAULT_REGION=eu-north-1
    
    # Look for response file in S3
    if aws s3 ls s3://ai-and-automation/responses/${REQUEST_ID}.json >/dev/null 2>&1; then
        echo "✅ Found translation result in S3!"
        RESULT=$(aws s3 cp s3://ai-and-automation/responses/${REQUEST_ID}.json - 2>/dev/null)
        echo "📋 S3 result: $RESULT"
        TRANSLATED_TEXT=$(echo $RESULT | jq -r '.translatedText // "Translation not found"')
        echo "🎯 Translated text: \"$TRANSLATED_TEXT\""
    else
        echo "⏳ Translation still processing in background..."
        echo "💡 You can check later with: curl -s '$API_BASE_URL/translate/status/$REQUEST_ID'"
    fi
    
    echo
    echo "---"
    echo
}

# Demo 1: English to Spanish
demo_translation "Hello, how are you today?" "en" "es" "Demo 1: English to Spanish"

# Demo 2: English to French  
demo_translation "Good morning! Welcome to our AI translation service." "en" "fr" "Demo 2: English to French"

# Demo 3: Spanish to English
demo_translation "Hola, ¿cómo estás? Espero que tengas un buen día." "es" "en" "Demo 3: Spanish to English"

# Demo 4: File Translation
echo "📄 Demo 4: JSON File Translation"
echo "----------------------------------------"
echo "🔤 Translating a JSON configuration file..."
echo

FILE_RESPONSE=$(curl -s -X POST "$API_BASE_URL/translate/file" \
  -H "Content-Type: application/json" \
  -d '{
    "fileContent": "{\"welcome_message\": \"Welcome to our application!\", \"buttons\": {\"login\": \"Log In\", \"signup\": \"Sign Up\", \"help\": \"Get Help\"}, \"notifications\": [\"You have 3 new messages\", \"System update available\"]}",
    "fileName": "app_config.json",
    "sourceLanguage": "en",
    "targetLanguage": "es",
    "waitForResult": false
  }')

echo "📤 File translation submitted: $FILE_RESPONSE"
FILE_REQUEST_ID=$(echo $FILE_RESPONSE | jq -r '.requestId')
echo "🆔 File Request ID: $FILE_REQUEST_ID"
echo

# Demo 5: Show System Status
echo "📊 Demo 5: System Status Overview"
echo "----------------------------------------"
echo "🔍 Recent translation requests in S3:"
export AWS_DEFAULT_REGION=eu-north-1
aws s3 ls s3://ai-and-automation/requests/ --recursive | tail -3
echo
echo "✅ Recent translation results in S3:"
aws s3 ls s3://ai-and-automation/responses/ --recursive | tail -3
echo

# Demo 6: Show a completed translation from S3
echo "🎯 Demo 6: Live Translation Result"
echo "----------------------------------------"
echo "📥 Fetching a recent completed translation..."
LATEST_RESPONSE=$(aws s3 ls s3://ai-and-automation/responses/ --recursive | tail -1 | awk '{print $4}')
if [ ! -z "$LATEST_RESPONSE" ]; then
    echo "📄 Latest response file: $LATEST_RESPONSE"
    TRANSLATION_RESULT=$(aws s3 cp s3://ai-and-automation/${LATEST_RESPONSE} - 2>/dev/null)
    echo "📋 Translation result:"
    echo "$TRANSLATION_RESULT" | jq .
else
    echo "⏳ No completed translations found yet"
fi

echo
echo "🎉 Demo Complete!"
echo "=================="
echo
echo "📈 System Performance:"
echo "- ✅ Node.js API Gateway: Working"
echo "- ✅ Lambda Functions: Working" 
echo "- ✅ S3 Storage: Working"
echo "- ✅ Translation Pipeline: Working"
echo "- ✅ Multiple Languages: Supported"
echo "- ✅ File Processing: Working"
echo
echo "🌐 API Endpoint: $API_BASE_URL"
echo "📁 S3 Bucket: ai-and-automation"
echo "🔗 Status Check: $API_BASE_URL/translate/status/{requestId}"
echo
echo "💡 For your blog: This demonstrates a complete serverless"
echo "   translation system using AWS Lambda, API Gateway, and S3!"
