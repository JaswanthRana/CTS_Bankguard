# Troubleshooting Guide for Gemini Decision Engine

## Internal Server Error - Debugging Steps

### Step 1: Verify Service is Running
```powershell
# Test health endpoint
Invoke-WebRequest -Uri "http://localhost:7000/api/gemini/health" -Method Get
```

**Expected Response:**
```json
{
  "status": "UP",
  "service": "Gemini Decision Engine",
  "version": "1.0.0"
}
```

**If this fails:**
- Service is not running, start it with: `./mvnw spring-boot:run`
- Port 7000 is blocked or not accessible

---

### Step 2: Check API Key Configuration
```powershell
# Check if environment variable is set
$env:GOOGLE_API_KEY
```

**If empty or null:**
```powershell
# Set the API key
$env:GOOGLE_API_KEY = "your-actual-api-key"

# Verify it's set
Write-Host $env:GOOGLE_API_KEY
```

---

### Step 3: Run the Test Script with Debug Mode
```powershell
# Run the test script
& "C:\Users\2485084\Documents\BankGaurd\test-gemini.ps1"
```

The script will show you:
- Exact request being sent
- Full response (or error details)
- Status and reason from decision engine

---

### Step 4: Check Console Logs

When you see the error, **immediately check the console output** in your IDE or terminal where the service is running.

Look for these log messages:

**Look for:** `DEBUG com.cts.gemini_test_try2.Service.GeminiService`

These will show:
- `Calling Gemini API with prompt length: XXX`
- `Attempting with model: gemini-2.0-flash`
- `Successfully received response from model: XXX` or `Model XXX failed: ...`

---

### Step 5: Common Error Messages & Solutions

#### Error 1: "All Gemini models failed"
```
ERROR: All Gemini models failed. Please check your API key and internet connection.
```

**Solutions:**
1. Verify API key is valid at https://makersuite.google.com/app/apikey
2. Check internet connection
3. Check if you're within API rate limits
4. Try setting environment variable: `$env:GOOGLE_API_KEY = "your-key"`

---

#### Error 2: "Could not resolve placeholder 'google.api.key'"
```
org.springframework.util.PlaceholderResolutionException: Could not resolve placeholder 'google.api.key'
```

**Solutions:**
1. Set environment variable: `$env:GOOGLE_API_KEY = "your-key"`
2. OR update `application.properties` with your key directly
3. Restart the service after setting the key

---

#### Error 3: "Model XXX failed: 401 Unauthorized"
```
Model gemini-2.0-flash failed: 401 Unauthorized
```

**Solutions:**
1. API key is invalid or expired
2. Get a new key from https://makersuite.google.com/app/apikey
3. Ensure the key has access to the Generative AI API

---

#### Error 4: "Error parsing Gemini response"
```
Error parsing Gemini response: Unexpected character in JSON
```

**Solutions:**
1. The JSON extraction from Gemini's response failed
2. Check the debug logs to see what Gemini returned
3. Try with a simpler prompt first

---

### Step 6: Test with Simple Prompt First

Before testing the full analysis, test with a simple prompt:

```powershell
$url = "http://localhost:7000/api/gemini/ask"
$payload = '"Is water wet?"'

$response = Invoke-WebRequest -Uri $url -Method Post -Body $payload -ContentType "application/json"
Write-Output $response.Content
```

**If this works:** API key is valid
**If this fails:** API key issue

---

### Step 7: Enable Maximum Debug Logging

Edit `application.properties` and set:
```properties
logging.level.root=DEBUG
logging.level.com.cts.gemini_test_try2=TRACE
logging.level.com.google.genai=DEBUG
```

Restart the service and run the test again. This will show **everything**.

---

## Quick Checklist

- [ ] Service running on port 7000
- [ ] Health check endpoint responds
- [ ] API key is valid (get from https://makersuite.google.com/app/apikey)
- [ ] Environment variable set: `$env:GOOGLE_API_KEY = "key"`
- [ ] Firewall not blocking port 7000
- [ ] Internet connection working
- [ ] JSON format is correct (all fields present)
- [ ] Checked console logs for error details

---

## Getting API Key

1. Visit: https://makersuite.google.com/app/apikey
2. Click "Get API Key" or "Create new API key"
3. Copy the key (it starts with `AIza...`)
4. Set it: `$env:GOOGLE_API_KEY = "AIza..."`
5. Restart service

---

## Manual cURL Test

```bash
curl -X POST http://localhost:7000/api/gemini/analyze-transaction \
  -H "Content-Type: application/json" \
  -d @payload.json
```

Where `payload.json` contains the JSON from earlier.

---

## If Everything Works But Still Getting Error

1. Share the **exact error message** from the console
2. Share the **response body** returned by the API
3. Check if logs show: `Successfully parsed response`
4. Check if logs show which model was used successfully

---

## Performance Notes

- First request might take 5-10 seconds (API warmup)
- Subsequent requests typically 1-3 seconds
- If timeout occurs, increase TimeoutSec in PowerShell script

---

Good luck! 🚀
