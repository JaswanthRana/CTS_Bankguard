# Rebuild and Test Instructions

## Step 1: Clean and Rebuild Both Services

### AlertCaseService
```powershell
cd C:\Users\2485163\OneDrive - Cognizant\Desktop\BankGG\Bankgaurd\AlertCaseService
mvn clean package -DskipTests
java -jar target/AlertCaseService-0.0.1-SNAPSHOT.jar
```

### enrichmentService (in new terminal)
```powershell
cd C:\Users\2485163\OneDrive - Cognizant\Desktop\BankGG\Bankgaurd\enrichmentService
mvn clean package -DskipTests
java -jar target/enrichmentService-1.0.0.jar
```

## Step 2: Send Test Transaction

```powershell
$FraudTransaction = @{
    transactionId = 999
    amount = 70000000
    city = $null
    state = $null
    ipAddress = $null
    riskScore = 0
    receiverAccountNumber = "FRAUD_TEST"
    customerId = 1
} | ConvertTo-Json

curl -X POST http://localhost:8089/api/transactions `
  -H "Content-Type: application/json" `
  -d $FraudTransaction
```

## Step 3: Verify Response

Look for:
```json
{
  "geminiDecision": {
    "decision": "terminated",
    "riskScore": 100.0
  },
  "alertSent": true    ← SHOULD BE TRUE! ✓
}
```

## Step 4: Check Alert Case Service

```powershell
# Get all alerts
curl http://localhost:8085/api/investigation/alerts

# Get all cases
curl http://localhost:8085/api/investigation/cases
```

## Expected Logs

### AlertCaseService startup should show:
```
Started AlertCaseServiceApplication in X seconds
```

(No WebClient.Builder errors)

### enrichmentService startup should show:
```
Started EnrichmentServiceApplication in X seconds
```

### When sending fraudulent transaction, AlertCaseService logs:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RECEIVED FRAUD ALERT FROM ENRICHMENT SERVICE
Decision: terminated, Risk Score: 100.0, Transaction ID: 999
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Fraud alert processed successfully
```

## Changes Made

1. **AlertCaseService/config/AppConfig.java**
   - Changed: `webClient(WebClient.Builder builder)` → `webClient()`
   - Now creates WebClient directly without builder injection

2. **enrichmentService/config/RestTemplateConfig.java**
   - Changed: `webClient(WebClient.Builder builder)` → `webClient()`
   - Changed: `restTemplate(RestTemplateBuilder builder)` → `restTemplate()`
   - Now both are created directly without builder injection

**Root Cause:** When both webmvc and webflux are on the classpath, Spring doesn't auto-provide Builder beans. Creating WebClient directly with `WebClient.create()` avoids this.
