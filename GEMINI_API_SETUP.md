# Decision Engine Service - Configuration Guide

## Issue Resolution: Missing Google Gemini API Key

### Error Fixed
The application was failing with:
```
PlaceholderResolutionException: Could not resolve placeholder 'google.api.key'
```

### Solution
You need to provide your Google Gemini API key. You have two options:

## Option 1: Set Environment Variable (Recommended for Production)
Set the `GOOGLE_API_KEY` environment variable:

**On Windows (PowerShell):**
```powershell
$env:GOOGLE_API_KEY = "your-api-key-here"
```

**On Windows (Command Prompt):**
```cmd
set GOOGLE_API_KEY=your-api-key-here
```

**On Linux/Mac:**
```bash
export GOOGLE_API_KEY=your-api-key-here
```

## Option 2: Update application.properties (For Development)
Edit `src/main/resources/application.properties` and replace:
```properties
google.api.key=${GOOGLE_API_KEY:YOUR_GOOGLE_GEMINI_API_KEY_HERE}
```

With your actual API key:
```properties
google.api.key=sk-your-actual-api-key-here
```

## Getting Your API Key

1. Visit: https://makersuite.google.com/app/apikey
2. Click "Get API Key"
3. Create a new API key for your project
4. Copy the key and use it in one of the options above

## File Changes Made

### 1. **GeminiConfig.java** (Updated)
- Now supports both environment variables and properties files
- Validates that the API key is properly configured
- Throws a clear error message if the key is missing or not set

### 2. **application.properties** (Updated)
- Added `google.api.key` property with default fallback to `GOOGLE_API_KEY` environment variable
- Added helpful comments with instructions

### 3. **pom.xml** (Updated)
- Added `jackson-databind` dependency for JSON parsing in Gemini responses

## Testing the Configuration

After setting your API key, run:
```bash
./mvnw spring-boot:run
```

Or from IDE, run the `GeminiTestTry2Application` class.

The application should start successfully on port 7000.

## Service Integration

Once the API key is configured, the decision engine will be available at:
- **Port:** 7000
- **Endpoint:** `POST /api/gemini/analyze-transaction`

The enrichment service can call this endpoint to get fraud analysis decisions.
