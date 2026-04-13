# Complete Transaction Enrichment Flow Test Script
# Tests the entire flow: Transaction Service → Enrichment Service → Decision Engine

Write-Host "===== BankGuard Transaction Enrichment & Decision Flow Test =====" -ForegroundColor Cyan
Write-Host "Testing complete flow with all three services" -ForegroundColor Yellow
Write-Host ""

# 1. Check all services are running
Write-Host "[Step 1] Verifying all services are running..." -ForegroundColor Yellow
Write-Host ""

$servicesStatus = @{
    "Transaction Service (8081)" = "http://localhost:8081/api/transactions"
    "Enrichment Service (8000)" = "http://localhost:8000/api/enrich/transaction"
    "Decision Engine (7000)" = "http://localhost:7000/api/gemini/analyze-transaction"
}

$allServicesRunning = $true

foreach ($service in $servicesStatus.GetEnumerator()) {
    try {
        $response = Invoke-WebRequest -Uri $service.Value -Method Options -UseBasicParsing -ErrorAction SilentlyContinue
        Write-Host "✓ $($service.Name) is running" -ForegroundColor Green
    } catch {
        Write-Host "✗ $($service.Name) is NOT running" -ForegroundColor Red
        $allServicesRunning = $false
    }
}

if (-not $allServicesRunning) {
    Write-Host ""
    Write-Host "ERROR: Not all services are running. Please start all services first:" -ForegroundColor Red
    Write-Host "  - Transaction Service: java -jar transactionService/target/transactionService-1.0.0.jar (port 8081)" -ForegroundColor Yellow
    Write-Host "  - Enrichment Service: java -jar enrichmentService/target/enrichmentService-1.0.0.jar (port 8000)" -ForegroundColor Yellow
    Write-Host "  - Decision Engine: java -jar Decision_Engine_service/target/gemini_test_try2-1.0.0.jar (port 7000)" -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "[Step 2] Creating test transaction..." -ForegroundColor Yellow
Write-Host ""

# Create transaction payload
$transactionPayload = @{
    amount = 5500
    city = "Bangalore"
    state = "Karnataka"
    ipAddress = "192.168.1.45"
    receiverAccountNumber = "SBI9876543210"
    customerId = 1
} | ConvertTo-Json

Write-Host "Request Payload:" -ForegroundColor Cyan
Write-Host $transactionPayload
Write-Host ""

# Send request
Write-Host "Sending to: http://localhost:8081/api/transactions" -ForegroundColor Yellow
Write-Host ""

try {
    $response = Invoke-WebRequest -Uri "http://localhost:8081/api/transactions" `
        -Method Post `
        -Body $transactionPayload `
        -ContentType "application/json" `
        -UseBasicParsing -ErrorAction Stop

    Write-Host "✓ Request successful! Status Code: $($response.StatusCode)" -ForegroundColor Green
    Write-Host ""
    
    $responseObj = $response.Content | ConvertFrom-Json
    
    Write-Host "[Step 3] Response from Transaction Service:" -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "Saved Transaction:" -ForegroundColor Cyan
    Write-Host ($responseObj.transaction | ConvertTo-Json -Depth 3)
    Write-Host ""
    
    Write-Host "Enrichment Service Response:" -ForegroundColor Cyan
    Write-Host ($responseObj.enrichmentResponse | ConvertTo-Json -Depth 5)
    Write-Host ""
    
    # Display decision
    if ($responseObj.enrichmentResponse.geminiDecision) {
        $decision = $responseObj.enrichmentResponse.geminiDecision
        Write-Host "═════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "GEMINI DECISION ANALYSIS" -ForegroundColor Cyan
        Write-Host "═════════════════════════════════════════════" -ForegroundColor Cyan
        Write-Host "Risk Score: $($decision.riskScore)" -ForegroundColor Yellow
        
        $decisionColor = if ($decision.decision -eq "genuine") { "Green" } 
                        elseif ($decision.decision -eq "flagged") { "Yellow" }
                        else { "Red" }
        
        Write-Host "Decision: $($decision.decision)" -ForegroundColor $decisionColor
        Write-Host "Reason: $($decision.reason)" -ForegroundColor White
        Write-Host "═════════════════════════════════════════════" -ForegroundColor Cyan
    }
    
    Write-Host ""
    Write-Host "✓ TEST PASSED - Complete flow executed successfully!" -ForegroundColor Green
    
} catch {
    Write-Host "✗ Error occurred:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    
    if ($_.Exception.Response) {
        Write-Host ""
        Write-Host "Response Details:" -ForegroundColor Yellow
        try {
            $errorContent = $_.Exception.Response.Content.ReadAsStream() | {  [System.IO.StreamReader]::new($_).ReadToEnd() }
            Write-Host $errorContent -ForegroundColor Yellow
        } catch {
            Write-Host "Could not read error response" -ForegroundColor Yellow
        }
    }
}

Write-Host ""
Write-Host "===== Test Complete =====" -ForegroundColor Cyan
