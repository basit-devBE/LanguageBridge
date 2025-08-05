# AI Translation Automation System

## 🌟 Overview

This is a complete AI-powered translation automation system built for Phase 3 of the AI Automation project. The system provides:

- **Text translation** via API endpoints
- **File translation** for JSON/TXT files  
- **Automated processing** using AWS Lambda
- **Real-time status checking**
- **Web interface** for easy interaction

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │   Node.js API   │    │   AWS Lambda    │
│   (HTML/JS)     │───►│   (Express)     │───►│  (Translation)  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │                       │
                                ▼                       ▼
                        ┌─────────────────┐    ┌─────────────────┐
                        │   AWS S3        │    │  AWS Translate  │
                        │   (Storage)     │    │   (Service)     │
                        └─────────────────┘    └─────────────────┘
```

## 📁 Project Structure

```
AI_Automation/
├── 📂 api/                          # Node.js Express API
│   ├── 📂 src/
│   │   ├── 🔧 aws.ts               # AWS S3 integration
│   │   ├── 🎯 main.ts              # Request handlers
│   │   ├── 🛣️ routes.ts            # API routes
│   │   └── 📤 multer.ts            # File upload config
│   ├── 📦 package.json
│   └── ⚙️ server.ts
├── 📂 lambda/                       # AWS Lambda function
│   └── 🐍 translation_handler.py   # Translation processor
├── 📂 infrastructure/               # Terraform deployment
│   └── 🏗️ main.tf                 # AWS infrastructure
├── 📂 frontend/                     # Web interface
│   └── 🌐 index.html              # Translation UI
├── 🚀 deploy.sh                    # Deployment script
└── 🧪 test_api.sh                  # API testing script
```

## 🚀 Quick Start

### 1. Start the API Server

```bash
cd api
npm install
npm run start:dev
```

### 2. Test the API

```bash
./test_api.sh
```

### 3. Open the Frontend

Open `frontend/index.html` in your browser or:
- Use VS Code's "Live Server" extension
- Visit: `file:///path/to/frontend/index.html`

## 🔌 API Endpoints

### Text Translation
```bash
POST /api/translate/text
Content-Type: application/json

{
  "text": "Hello world",
  "sourceLanguage": "en",
  "targetLanguage": "es"
}
```

### File Translation
```bash
POST /api/translate/file
Content-Type: multipart/form-data

file: [JSON/TXT file]
sourceLanguage: "en"
targetLanguage: "es"
```

### Status Check
```bash
GET /api/translate/status/:requestId
```

## 🔧 Configuration

### Environment Variables (.env)

```bash
AWS_ACCESS_KEY=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
AWS_REGION=eu-north-1
AWS_S3_BUCKET_NAME=ai-and-automation
```

### AWS Requirements

- S3 bucket: `ai-and-automation`
- Lambda function with translation permissions
- S3 event triggers for `requests/` folder

## 🏗️ AWS Deployment

### 1. Configure AWS CLI

```bash
aws configure
```

### 2. Deploy Infrastructure

```bash
./deploy.sh
```

This will:
- Create Lambda function
- Set up S3 event triggers
- Configure IAM permissions
- Deploy translation automation

### 3. Verify Deployment

```bash
aws lambda list-functions
aws s3 ls s3://ai-and-automation/
```

## 📊 S3 Bucket Structure

```
ai-and-automation/
├── requests/     # API uploads translation requests here
├── responses/    # Lambda outputs completed translations
├── logs/         # Processing logs and metadata
└── errors/       # Error logs and debugging info
```

## 🔄 Translation Workflow

1. **Request Submission**
   - User submits text/file via API or frontend
   - Request uploaded to S3 `requests/` folder
   - Unique request ID generated

2. **Processing**
   - S3 event triggers Lambda function
   - Lambda downloads request from S3
   - AWS Translate processes the text
   - Results uploaded to S3 `responses/` folder

3. **Result Retrieval**
   - Client polls status endpoint
   - API checks S3 `responses/` folder
   - Returns completed translation

## 🧪 Testing

### API Testing
```bash
./test_api.sh
```

### Manual Testing
```bash
# Test text translation
curl -X POST http://localhost:3000/api/translate/text \
  -H "Content-Type: application/json" \
  -d '{"text":"Hello","targetLanguage":"es"}'

# Check status
curl http://localhost:3000/api/translate/status/{REQUEST_ID}
```

### Frontend Testing
1. Open `frontend/index.html`
2. Enter text to translate
3. Select languages
4. Click "Translate"
5. Wait for results

## 🌍 Supported Languages

- 🇺🇸 English (en)
- 🇪🇸 Spanish (es)  
- 🇫🇷 French (fr)
- 🇩🇪 German (de)
- 🇮🇹 Italian (it)
- 🇵🇹 Portuguese (pt)
- 🇷🇺 Russian (ru)
- 🇯🇵 Japanese (ja)
- 🇰🇷 Korean (ko)
- 🇨🇳 Chinese (zh)
- 🇸🇦 Arabic (ar)

## 🛠️ Troubleshooting

### Common Issues

1. **API not starting**
   - Check port 3000 availability
   - Verify dependencies: `npm install`
   - Check environment variables

2. **S3 access denied**
   - Verify AWS credentials
   - Check bucket permissions
   - Ensure bucket exists in correct region

3. **Lambda function errors**
   - Check CloudWatch logs
   - Verify IAM permissions
   - Test function independently

4. **Translation not working**
   - Verify S3 event triggers
   - Check Lambda function deployment
   - Monitor CloudWatch logs

### Debugging

```bash
# Check API logs
npm run start:dev

# Check AWS resources
aws s3 ls s3://ai-and-automation/
aws lambda get-function --function-name ai-automation-translation-handler
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/ai-automation"
```

## 📈 Monitoring

### CloudWatch Logs
- Lambda execution logs
- Error tracking
- Performance metrics

### S3 Monitoring  
- Request/response file counts
- Processing times
- Error rates

## 🔮 Future Enhancements

- [ ] **Batch Translation** - Process multiple files
- [ ] **Real-time WebSocket** - Live translation updates  
- [ ] **Translation History** - Store and search past translations
- [ ] **Custom Models** - Industry-specific translations
- [ ] **API Rate Limiting** - Prevent abuse
- [ ] **Authentication** - User accounts and API keys
- [ ] **Analytics Dashboard** - Usage statistics

## 📄 License

This project is part of the AI Automation Phase 3 implementation.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

---

**Built with ❤️ for AI Automation Phase 3**
