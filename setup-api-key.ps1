# API Key Validation & Setup Guide

Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Google Gemini API Key Setup" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
Write-Host ""

# Check current environment variable
$currentKey = $env:GOOGLE_API_KEY
if ($currentKey) {
    Write-Host "Current GOOGLE_API_KEY in env:" -ForegroundColor Yellow
    Write-Host "$($currentKey.Substring(0, [Math]::Min(10, $currentKey.Length)))..." -ForegroundColor Gray
} else {
    Write-Host "No GOOGLE_API_KEY environment variable set" -ForegroundColor Red
}

Write-Host ""
Write-Host "STEP 1: Get Your Free API Key" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
Write-Host "1. Go to: https://makersuite.google.com/app/apikey" -ForegroundColor Yellow
Write-Host "2. Click 'Create API Key' or 'Get API Key'" -ForegroundColor Yellow
Write-Host "3. Select or create a Google Cloud project" -ForegroundColor Yellow
Write-Host "4. Copy the generated API key (looks like: AIza...)" -ForegroundColor Yellow
Write-Host ""

Write-Host "STEP 2: Set the API Key (Choose ONE method):" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green

Write-Host ""
Write-Host "Method A: Set Environment Variable (Recommended)" -ForegroundColor Cyan
Write-Host "Copy and run this in PowerShell:" -ForegroundColor Gray
Write-Host ""
Write-Host '$env:GOOGLE_API_KEY = "YOUR_API_KEY_HERE"' -ForegroundColor White
Write-Host ""
Write-Host "Then verify with:" -ForegroundColor Gray
Write-Host '$env:GOOGLE_API_KEY' -ForegroundColor White
Write-Host ""

Write-Host ""
Write-Host "Method B: Update application.properties" -ForegroundColor Cyan
Write-Host "Edit: decisionEngineService\src\main\resources\application.properties" -ForegroundColor Gray
Write-Host "Change this line:" -ForegroundColor Gray
Write-Host 'google.api.key=${GOOGLE_API_KEY:AIzaSyCbzpn5j6qfmxO_6xF750h5fsXYWNOyLK4}' -ForegroundColor White
Write-Host ""
Write-Host "To:" -ForegroundColor Gray
Write-Host 'google.api.key=${GOOGLE_API_KEY:YOUR_ACTUAL_API_KEY}' -ForegroundColor White
Write-Host ""

Write-Host ""
Write-Host "STEP 3: Restart the Service" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green
Write-Host "1. Stop the running service (Ctrl+C in the terminal)" -ForegroundColor Yellow
Write-Host "2. Run: ./mvnw spring-boot:run" -ForegroundColor Yellow
Write-Host "3. Wait for 'Application started' message" -ForegroundColor Yellow
Write-Host ""

Write-Host ""
Write-Host "STEP 4: Test the API Key" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green

Write-Host ""
Write-Host "Option 1: Test with Health Check" -ForegroundColor Cyan
Write-Host "Run this in a new PowerShell window:" -ForegroundColor Gray
$healthCommand = 'Invoke-WebRequest -Uri "http://localhost:7000/api/gemini/health" -Method Get'
Write-Host "$healthCommand" -ForegroundColor White
Write-Host ""

Write-Host ""
Write-Host "Option 2: Test with Full Script" -ForegroundColor Cyan
Write-Host "Run:" -ForegroundColor Gray
Write-Host '& "C:\Users\2485084\Documents\BankGaurd\test-gemini.ps1"' -ForegroundColor White
Write-Host ""

Write-Host ""
Write-Host "Troubleshooting:" -ForegroundColor Magenta
Write-Host "================================" -ForegroundColor Magenta
Write-Host "Q: Still getting 'All Gemini models failed'?" -ForegroundColor Yellow
Write-Host "A1: Your API key might be invalid. Get a new one from" -ForegroundColor Gray
Write-Host "   https://makersuite.google.com/app/apikey" -ForegroundColor Gray
Write-Host "A2: Make sure you're using the FULL API key (starts with AIza)" -ForegroundColor Gray
Write-Host "A3: Restart the service after updating the key" -ForegroundColor Gray
Write-Host ""

Write-Host "Q: Can't access https://makersuite.google.com/app/apikey?" -ForegroundColor Yellow
Write-Host "A: Use https://aistudio.google.com instead" -ForegroundColor Gray
Write-Host ""

Write-Host "Q: Getting different error?" -ForegroundColor Yellow
Write-Host "A: Check the console logs where your service is running" -ForegroundColor Gray
Write-Host "   Look for: 'Attempting with model:' messages" -ForegroundColor Gray
Write-Host ""

Write-Host ""
Write-Host "================================" -ForegroundColor Cyan
Write-Host "Ready? Run the test script once you've set your API key!" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan
