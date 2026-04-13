# Simple API Key Test - Run this to verify your API key works

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Simple Gemini API Key Validation Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$apiUrl = "http://localhost:7000/api/gemini/ask"
$headers = @{
    "Content-Type" = "application/json"
}

# Simple test prompt
$testPrompt = "Respond with just one word: working"
$jsonBody = ConvertTo-Json $testPrompt

Write-Host "Testing basic API connectivity..." -ForegroundColor Yellow
Write-Host "URL: $apiUrl" -ForegroundColor Gray
Write-Host "Prompt: $testPrompt" -ForegroundColor Gray
Write-Host ""

try {
    Write-Host "Sending request..." -ForegroundColor Cyan
    
    $response = Invoke-WebRequest -Uri $apiUrl `
        -Method Post `
        -Body $jsonBody `
        -Headers $headers `
        -TimeoutSec 30 `
        -ErrorAction Stop

    Write-Host "✓ SUCCESS!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Response Status: $($response.StatusCode)" -ForegroundColor Green
    Write-Host "Response Content:" -ForegroundColor Green
    Write-Host "$($response.Content)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Your API key is VALID! ✓" -ForegroundColor Green
    
} catch {
    Write-Host "✗ FAILED" -ForegroundColor Red
    Write-Host ""
    
    if ($_.Exception.Message -like "*All Gemini models failed*") {
        Write-Host "Error: API Key is INVALID or doesn't have Gemini API access" -ForegroundColor Red
        Write-Host ""
        Write-Host "Fix: Get a new API key from https://makersuite.google.com/app/apikey" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Steps:" -ForegroundColor Yellow
        Write-Host "1. Visit: https://makersuite.google.com/app/apikey" -ForegroundColor Gray
        Write-Host "2. Click 'Create API Key'" -ForegroundColor Gray
        Write-Host "3. Copy the key (it starts with AIza...)" -ForegroundColor Gray
        Write-Host "4. Run: `$env:GOOGLE_API_KEY = 'your-key-here'" -ForegroundColor Gray
        Write-Host "5. Run: ./mvnw spring-boot:run" -ForegroundColor Gray
        Write-Host "6. Run this script again" -ForegroundColor Gray
        
    } elseif ($_.Exception.Message -like "*Connection refused*") {
        Write-Host "Error: Cannot connect to service on port 7000" -ForegroundColor Red
        Write-Host ""
        Write-Host "Fix: Start the decision engine service first:" -ForegroundColor Yellow
        Write-Host "cd decisionEngineService" -ForegroundColor Gray
        Write-Host "./mvnw spring-boot:run" -ForegroundColor Gray
        
    } else {
        Write-Host "Error: " + $_.Exception.Message -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "Full error details:" -ForegroundColor Yellow
    if ($_.ErrorDetails) {
        Write-Host $_.ErrorDetails.Message -ForegroundColor Red
    }
    
    if ($_.Exception.Response) {
        Write-Host "HTTP Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Yellow
        $streamReader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        $errorBody = $streamReader.ReadToEnd()
        Write-Host "Response: $errorBody" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test completed" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
