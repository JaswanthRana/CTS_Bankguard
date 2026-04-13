# Test Transaction Creation with Enrichment Flow
# This script tests the complete flow:
# 1. POST transaction to Transaction Service
# 2. Transaction Service sends to Enrichment Service
# 3. Enrichment Service processes and returns enriched response

Write-Host "===== Transaction Creation with Enrichment Test =====" -ForegroundColor Cyan

# First, verify all services are running
Write-Host "`nChecking services..." -ForegroundColor Yellow

# Check Enrichment Service
try {
    $enrichmentCheck = Invoke-WebRequest -Uri "http://localhost:8082/api/enrich/transaction" `
        -Method Post -Body '{}' -ContentType "application/json" -ErrorAction Stop
    Write-Host "✓ Enrichment Service is running on port 8082" -ForegroundColor Green
} catch {
    Write-Host "✗ Enrichment Service is NOT running on port 8082" -ForegroundColor Red
}

# Create transaction payload
$transactionPayload = @{
    amount = 400
    city = "Chennai"
    state = "Tamil Nadu"
    ipAddress = "192.168.1.25"
    receiverAccountNumber = "SBI9876543210"
    customerId = 1
} | ConvertTo-Json

Write-Host "`nTransaction Payload:" -ForegroundColor Yellow
Write-Host $transactionPayload

# Test creating transaction via Transaction Service
Write-Host "`nSending transaction creation request to Transaction Service..." -ForegroundColor Yellow
Write-Host "URL: http://localhost:8081/api/transactions" -ForegroundColor Cyan

try {
    $response = Invoke-WebRequest -Uri "http://localhost:8081/api/transactions" `
        -Method Post `
        -Body $transactionPayload `
        -ContentType "application/json" `
        -ErrorAction Stop

    Write-Host "`n✓ Request successful!" -ForegroundColor Green
    Write-Host "Status Code: $($response.StatusCode)" -ForegroundColor Green
    
    $responseContent = $response.Content | ConvertFrom-Json
    Write-Host "`nResponse:" -ForegroundColor Cyan
    Write-Host ($responseContent | ConvertTo-Json -Depth 5)
    
    Write-Host "`n✓ Transaction created successfully!" -ForegroundColor Green
    Write-Host "Now check the enrichment service response above." -ForegroundColor Cyan

} catch {
    Write-Host "`n✗ Error creating transaction:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    
    if ($_.Exception.Response) {
        Write-Host "Response Body:" -ForegroundColor Yellow
        Write-Host $_.Exception.Response.Content -ForegroundColor Yellow
    }
}

Write-Host "`n===== Test Complete =====" -ForegroundColor Cyan
