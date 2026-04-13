# Test script for Gemini API - Save this as test-gemini.ps1

# Clear screen
Clear-Host

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "BankGuard Gemini API Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Configuration
$apiUrl = "http://localhost:7000/api/gemini/analyze-transaction"
$headers = @{
    "Content-Type" = "application/json"
}

# Test JSON payload
$testPayload = @{
    transactionId = 12345
    amount = 5000.00
    city = "New York"
    state = "NY"
    time = "2026-04-09T18:09:13Z"
    riskScore = 35.0
    customerId = 1
    customerName = "John Doe"
    customerEmail = "john@example.com"
    customerAccountNo = "ACC123456"
    customerBalance = 50000.00
    previousTransactions = @(
        @{
            transactionId = 12341
            amount = 150.00
            city = "New York"
            state = "NY"
            ipAddress = "192.168.1.1"
            time = "2026-04-05T15:30:00Z"
            riskScore = 15.0
            customerId = 1
        },
        @{
            transactionId = 12342
            amount = 250.00
            city = "New York"
            state = "NY"
            ipAddress = "192.168.1.1"
            time = "2026-04-06T10:15:00Z"
            riskScore = 18.0
            customerId = 1
        },
        @{
            transactionId = 12343
            amount = 300.00
            city = "Boston"
            state = "MA"
            ipAddress = "192.168.1.2"
            time = "2026-04-07T14:45:00Z"
            riskScore = 25.0
            customerId = 1
        },
        @{
            transactionId = 12344
            amount = 2000.00
            city = "New York"
            state = "NY"
            ipAddress = "192.168.1.1"
            time = "2026-04-08T09:20:00Z"
            riskScore = 20.0
            customerId = 1
        },
        @{
            transactionId = 12345
            amount = 500.00
            city = "Philadelphia"
            state = "PA"
            ipAddress = "192.168.1.3"
            time = "2026-04-08T16:00:00Z"
            riskScore = 22.0
            customerId = 1
        }
    )
}

# Convert to JSON
$jsonBody = $testPayload | ConvertTo-Json -Depth 10

Write-Host "Request URL: $apiUrl" -ForegroundColor Yellow
Write-Host "Request Method: POST" -ForegroundColor Yellow
Write-Host ""
Write-Host "Request Body:" -ForegroundColor Yellow
Write-Host "$jsonBody" -ForegroundColor Gray
Write-Host ""

# Make the request
try {
    Write-Host "Sending request..." -ForegroundColor Cyan
    $response = Invoke-WebRequest -Uri $apiUrl `
        -Method Post `
        -Body $jsonBody `
        -Headers $headers `
        -TimeoutSec 30 `
        -ErrorAction Stop

    Write-Host "✓ Request successful!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Response Status: $($response.StatusCode) $($response.StatusDescription)" -ForegroundColor Green
    Write-Host ""
    Write-Host "Response Body:" -ForegroundColor Yellow
    
    # Pretty print the response
    $responseJson = $response.Content | ConvertFrom-Json
    Write-Host ($responseJson | ConvertTo-Json -Depth 10) -ForegroundColor Green
    
    # Extract key information
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Analysis Results:" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Status: $($responseJson.status)" -ForegroundColor $(if($responseJson.status -eq 'genuine') { 'Green' } else { 'Yellow' })
    Write-Host "Updated Risk Score: $($responseJson.updatedRiskScore)" -ForegroundColor Cyan
    Write-Host "Reason: $($responseJson.reason)" -ForegroundColor Cyan
    
} catch {
    Write-Host "✗ Request failed!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Error Details:" -ForegroundColor Yellow
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    
    # Try to extract more details
    if ($_.ErrorDetails) {
        Write-Host "Error Response:" -ForegroundColor Yellow
        Write-Host $_.ErrorDetails.Message -ForegroundColor Red
    }
    
    if ($_.Exception.Response) {
        Write-Host ""
        Write-Host "HTTP Status: $($_.Exception.Response.StatusCode)" -ForegroundColor Yellow
        $streamReader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
        $errorBody = $streamReader.ReadToEnd()
        Write-Host "Response Body:" -ForegroundColor Yellow
        Write-Host $errorBody -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Test completed!" -ForegroundColor Cyan
