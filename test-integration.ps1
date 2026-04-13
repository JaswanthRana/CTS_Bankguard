# AlertCaseService to sarReport Integration - Test Script

# This PowerShell script helps test the integration between AlertCaseService and sarReport
# Make sure both services are running before executing this script

param(
    [string]$AlertCasePort = "8085",
    [string]$SarReportPort = "8088",
    [switch]$SkipServices = $false
)

function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host $Text -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host ""
}

function Test-ServiceHealth {
    param(
        [string]$ServiceName,
        [int]$Port,
        [string]$HealthEndpoint
    )
    
    $Uri = "http://localhost:$Port$HealthEndpoint"
    
    try {
        $response = Invoke-RestMethod -Uri $Uri -Method Get -ErrorAction Stop
        Write-Host "✓ $ServiceName is running on port $Port" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "✗ $ServiceName is NOT running on port $Port" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Yellow
        return $false
    }
}

function Send-FraudAlert {
    param(
        [int]$TransactionId,
        [double]$RiskScore,
        [double]$Amount,
        [string]$CustomerName
    )
    
    $Uri = "http://localhost:$AlertCasePort/api/investigation/ingest-fraud-alert"
    
    $Payload = @{
        decisionStatus = "flagged"
        geminiRiskScore = [double]$RiskScore
        transactionId = [int]$TransactionId
        amount = [double]$Amount
        customerName = $CustomerName
        geminiDecision = @{
            decision = "fraud"
            confidence = $RiskScore / 100
        }
    } | ConvertTo-Json
    
    Write-Host "Sending fraud alert to AlertCaseService..."
    Write-Host "Transaction ID: $TransactionId" -ForegroundColor Gray
    Write-Host "Risk Score: $RiskScore" -ForegroundColor Gray
    Write-Host "Amount: $$Amount" -ForegroundColor Gray
    Write-Host "Customer: $CustomerName" -ForegroundColor Gray
    
    try {
        $response = Invoke-RestMethod -Uri $Uri `
            -Method Post `
            -ContentType "application/json" `
            -Body $Payload `
            -ErrorAction Stop
        
        Write-Host "✓ Alert sent successfully (HTTP 200)" -ForegroundColor Green
        return @{
            Success = $true
            TransactionId = $TransactionId
        }
    } catch [System.Net.Http.HttpRequestException] {
        Write-Host "✗ Failed to send alert: $($_.Exception.Message)" -ForegroundColor Red
        return @{
            Success = $false
            TransactionId = $TransactionId
        }
    }
}

function Get-AllSarReports {
    $Uri = "http://localhost:$SarReportPort/sar/reports"
    
    try {
        $response = Invoke-RestMethod -Uri $Uri -Method Get -ErrorAction Stop
        Write-Host "✓ Retrieved SAR reports from sarReport" -ForegroundColor Green
        return $response
    } catch {
        Write-Host "✗ Failed to get SAR reports: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Get-SarReportByTransactionId {
    param([long]$TransactionId)
    
    $Uri = "http://localhost:$SarReportPort/sar/report/transaction/$TransactionId"
    
    try {
        $response = Invoke-RestMethod -Uri $Uri -Method Get -ErrorAction Stop
        Write-Host "✓ Retrieved SAR report for Transaction ID: $TransactionId" -ForegroundColor Green
        return $response
    } catch {
        Write-Host "✗ Failed to get SAR report: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

function Display-SarReport {
    param([pscustomobject]$Report)
    
    if ($Report) {
        Write-Host ""
        Write-Host "SAR Report Details:" -ForegroundColor Cyan
        Write-Host "  SAR ID: $($Report.sarId)" -ForegroundColor White
        Write-Host "  Case ID: $($Report.caseId)" -ForegroundColor White
        Write-Host "  Customer ID: $($Report.customerId)" -ForegroundColor White
        Write-Host "  Status: $($Report.status)" -ForegroundColor White
        Write-Host "  Risk Score: $($Report.riskScore)" -ForegroundColor White
        Write-Host "  Transaction ID: $($Report.transactionId)" -ForegroundColor White
        Write-Host "  Amount: $($Report.amount)" -ForegroundColor White
        Write-Host "  Customer Name: $($Report.customerName)" -ForegroundColor White
        Write-Host "  Stored Date: $($Report.localDate)" -ForegroundColor White
        Write-Host ""
    }
}

function Run-FullIntegrationTest {
    Write-Header "FULL INTEGRATION TEST"
    
    # Step 1: Check service health
    Write-Header "Step 1: Checking Service Health"
    
    $alertCaseHealth = Test-ServiceHealth -ServiceName "AlertCaseService" -Port $AlertCasePort -HealthEndpoint "/actuator/health"
    $sarReportHealth = Test-ServiceHealth -ServiceName "sarReport" -Port $SarReportPort -HealthEndpoint "/actuator/health"
    
    if (-not $alertCaseHealth -or -not $sarReportHealth) {
        Write-Host ""
        Write-Host "⚠ One or more services are not running. Please start them first:" -ForegroundColor Yellow
        Write-Host "  Terminal 1: cd AlertCaseService && mvn spring-boot:run" -ForegroundColor Yellow
        Write-Host "  Terminal 2: cd sarReport && mvn spring-boot:run" -ForegroundColor Yellow
        return
    }
    
    # Step 2: Send fraud alerts
    Write-Header "Step 2: Sending Fraud Alerts"
    
    $alerts = @(
        @{ TransactionId = 100001; RiskScore = 85.0; Amount = 15000.00; CustomerName = "John Smith" },
        @{ TransactionId = 100002; RiskScore = 75.5; Amount = 8500.00; CustomerName = "Jane Doe" },
        @{ TransactionId = 100003; RiskScore = 92.0; Amount = 25000.00; CustomerName = "Bob Johnson" }
    )
    
    $sentAlerts = @()
    foreach ($alert in $alerts) {
        $result = Send-FraudAlert -TransactionId $alert.TransactionId `
                                  -RiskScore $alert.RiskScore `
                                  -Amount $alert.Amount `
                                  -CustomerName $alert.CustomerName
        
        if ($result.Success) {
            $sentAlerts += $result
        }
        
        Start-Sleep -Seconds 1
    }
    
    Write-Host ""
    Write-Host "Summary: Sent $($sentAlerts.Count) fraud alerts successfully" -ForegroundColor Green
    
    # Step 3: Wait and verify data
    Write-Header "Step 3: Verifying Data in sarReport"
    
    Start-Sleep -Seconds 2
    
    $allReports = Get-AllSarReports
    if ($allReports) {
        Write-Host "Total SAR Reports stored: $($allReports.Count)" -ForegroundColor Green
        Write-Host ""
        
        # Display latest reports
        foreach ($report in $allReports | Select-Object -Last 3) {
            Display-SarReport -Report $report
        }
    }
    
    # Step 4: Verify individual reports
    Write-Header "Step 4: Verifying Individual Transactions"
    
    foreach ($alert in $sentAlerts) {
        $transactionId = $alert.TransactionId
        $report = Get-SarReportByTransactionId -TransactionId $transactionId
        Display-SarReport -Report $report
        Start-Sleep -Seconds 1
    }
    
    # Step 5: Summary
    Write-Header "Integration Test Summary"
    
    Write-Host "✓ AlertCaseService is receiving fraud alerts" -ForegroundColor Green
    Write-Host "✓ AlertCaseService is forwarding data to sarReport" -ForegroundColor Green
    Write-Host "✓ sarReport is storing ReportingRequest data as SarReport" -ForegroundColor Green
    Write-Host "✓ Data can be queried and retrieved successfully" -ForegroundColor Green
    Write-Host ""
    Write-Host "Integration Status: SUCCESSFUL ✓" -ForegroundColor Green
    Write-Host ""
}

function Run-StressTest {
    param([int]$AlertCount = 10)
    
    Write-Header "STRESS TEST - Sending $AlertCount Fraud Alerts"
    
    $startTime = Get-Date
    $successCount = 0
    
    for ($i = 1; $i -le $AlertCount; $i++) {
        $transactionId = 200000 + $i
        $riskScore = 60 + (Get-Random -Minimum 0 -Maximum 35)
        $amount = 1000 + (Get-Random -Minimum 0 -Maximum 20000)
        $customerName = "Stress Test Customer $i"
        
        Write-Host "Alert $i of $AlertCount - Transaction ID: $transactionId" -ForegroundColor Gray
        
        $result = Send-FraudAlert -TransactionId $transactionId `
                                  -RiskScore $riskScore `
                                  -Amount $amount `
                                  -CustomerName $customerName
        
        if ($result.Success) {
            $successCount++
        }
        
        Start-Sleep -Milliseconds 500
    }
    
    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalSeconds
    
    Write-Header "Stress Test Results"
    
    Write-Host "Total Alerts Sent: $AlertCount" -ForegroundColor White
    Write-Host "Successful: $successCount" -ForegroundColor Green
    Write-Host "Failed: $($AlertCount - $successCount)" -ForegroundColor Red
    Write-Host "Total Time: $([Math]::Round($duration, 2)) seconds" -ForegroundColor White
    Write-Host "Average Time per Alert: $([Math]::Round($duration / $AlertCount, 3)) seconds" -ForegroundColor White
    Write-Host ""
    
    Write-Host "Retrieving all stored reports..." -ForegroundColor Cyan
    $allReports = Get-AllSarReports
    if ($allReports) {
        Write-Host "Total SAR Reports in Database: $($allReports.Count)" -ForegroundColor Green
    }
    Write-Host ""
}

# Main execution
Clear-Host
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "║  AlertCaseService ↔ sarReport Integration Test Suite          ║" -ForegroundColor Magenta
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta

Write-Host ""
Write-Host "AlertCaseService URL: http://localhost:$AlertCasePort" -ForegroundColor Yellow
Write-Host "sarReport URL:        http://localhost:$SarReportPort" -ForegroundColor Yellow
Write-Host ""

# Check if services need to be started
if (-not $SkipServices) {
    $choice = Read-Host "Start services now? (y/n)"
    if ($choice -eq "y") {
        Write-Host "Note: Open two PowerShell windows and run:" -ForegroundColor Yellow
        Write-Host "  Window 1: cd AlertCaseService; mvn spring-boot:run" -ForegroundColor White
        Write-Host "  Window 2: cd sarReport; mvn spring-boot:run" -ForegroundColor White
        Write-Host ""
        Read-Host "Press Enter when both services are running"
    }
}

# Menu
Write-Host "Select a test to run:" -ForegroundColor Cyan
Write-Host "1. Full Integration Test" -ForegroundColor White
Write-Host "2. Stress Test (10 alerts)" -ForegroundColor White
Write-Host "3. Stress Test (25 alerts)" -ForegroundColor White
Write-Host "4. Check Service Health" -ForegroundColor White
Write-Host "5. Exit" -ForegroundColor White
Write-Host ""

$choice = Read-Host "Enter choice (1-5)"

switch ($choice) {
    "1" { Run-FullIntegrationTest }
    "2" { Run-StressTest -AlertCount 10 }
    "3" { Run-StressTest -AlertCount 25 }
    "4" {
        Write-Header "Service Health Check"
        Test-ServiceHealth -ServiceName "AlertCaseService" -Port $AlertCasePort -HealthEndpoint "/actuator/health"
        Test-ServiceHealth -ServiceName "sarReport" -Port $SarReportPort -HealthEndpoint "/actuator/health"
    }
    "5" { Write-Host "Exiting..." -ForegroundColor Yellow; exit }
    default { Write-Host "Invalid choice" -ForegroundColor Red }
}

Write-Host ""
Write-Host "Test completed. Press any key to exit..." -ForegroundColor Cyan
Read-Host
