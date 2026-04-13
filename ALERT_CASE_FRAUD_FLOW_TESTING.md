# Alert Case Service - Fraud Alert Flow - Testing & Troubleshooting

## ✅ ISSUE FIXED

**Problem**: AlertCaseService is on **port 8085**, but enrichmentService was sending to **port 8005**

**Solution Applied**:
1. ✅ Updated `application.properties` to `external.alertcase-service.url=http://localhost:8085`
2. ✅ Enhanced AlertCaseClient with detailed logging
3. ✅ Enhanced EnrichmentService with step-by-step logging
4. ✅ Added @Slf4j for better debugging

---

## Complete Alert Flow

```
transactionService (POST /api/transactions)
    ↓
enrichmentService (POST /api/enrich/transaction/with-decision-and-alert)
    ↓
Step 1: Enrich transaction
    - Add customer info
    - Add previous 5 transactions
    ↓
Step 2: Convert to DecisionRequest
    ↓
Step 3: Call Decision_Engine_Service (Gemini)
    ↓
Step 4: Get GeminiDecisionResponse
    ↓
Step 5: Decision Check
    ├─ IF decision = "flagged" OR "terminated"
    │   ├─ Create AlertCasePayload
    │   ├─ Call AlertCaseClient.sendToAlertCase()
    │   ├─ POST to http://localhost:8085/api/investigation/ingest-fraud-alert
    │   └─ alertSent = TRUE
    │
    └─ IF decision = "genuine"
        └─ alertSent = FALSE (no alert)
    ↓
Return TransactionDecisionResponse with alertSent boolean
```

---

## Testing the Complete Flow

### 1. Start All Services

Ensure these are running:
```bash
# AlertCaseService on port 8085
java -jar AlertCaseService.jar

# Decision_Engine_Service on port 7002
java -jar Decision_Engine_service.jar

# enrichmentService on port 8010
java -jar enrichmentService.jar

# transactionService on port 8089
java -jar transactionService.jar
```

### 2. Test with a Fraudulent Transaction

```bash
curl -X POST http://localhost:8089/api/transactions \
  -H "Content-Type: application/json" \
  -d '{
    "transactionId": 100,
    "amount": 70000000,
    "city": null,
    "state": null,
    "ipAddress": null,
    "riskScore": 0,
    "receiverAccountNumber": "HDFC987654321",
    "customerId": 1
  }'
```

**Expected Response:**
```json
{
  "enrichedTransaction": {...},
  "geminiDecision": {
    "decision": "terminated",
    "riskScore": 100.0,
    "reason": "..."
  },
  "alertSent": true    // ← THIS SHOULD BE TRUE NOW!
}
```

### 3. Verify Alert Created in AlertCaseService

```bash
# Get all alerts
curl http://localhost:8085/api/investigation/alerts

# Get all cases
curl http://localhost:8085/api/investigation/cases

# Get specific case
curl http://localhost:8085/api/investigation/cases/CAS-<uuid>
```

---

## Log Verification

### Check enrichmentService logs for these messages:

```
[INFO] Step 1: Enriching transaction for customer: 1
[INFO] Step 2: Converting enriched transaction to decision request
[INFO] Step 3: Getting Gemini decision for transaction amount: 7.0E7
[INFO] Step 3 Result: Gemini Decision = terminated, Risk Score = 100.0
[WARN] FRAUD DETECTED: Creating alert for flagged/terminated transaction...
[INFO] Sending alert payload to AlertCaseService...
```

### Check AlertCaseClient logs:

```
[INFO] Sending fraud alert to AlertCaseService at: http://localhost:8085/api/investigation/ingest-fraud-alert
[DEBUG] Alert payload - Decision: terminated, Risk Score: 100.0, Transaction ID: 16
[INFO] Successfully sent fraud alert to AlertCaseService. Risk Score: 100.0, Decision: terminated
```

### Console output:

```
✓ Fraud alert successfully sent to AlertCaseService at: http://localhost:8085/api/investigation/ingest-fraud-alert
✓ Transaction flagged/terminated - Alert sent to AlertCaseService
```

---

## Troubleshooting Checklist

### Issue: `alertSent still showing false`

**Check:**
1. ✅ Is AlertCaseService running on port 8085?
   ```bash
   netstat -ano | findstr :8085  # Windows
   lsof -i :8085                 # Mac/Linux
   ```

2. ✅ Is enrichmentService using the correct URL?
   ```bash
   # Check application.properties
   cat enrichmentService/src/main/resources/application.properties
   # Should show: external.alertcase-service.url=http://localhost:8085
   ```

3. ✅ Did you restart enrichmentService after config change?
   - If you changed application.properties, restart the service
   - Spring might cache the value otherwise

4. ✅ Check service logs for connection errors
   ```
   Failed to send fraud alert to AlertCaseService at http://localhost:8005
   ```
   If you still see port 8005, the config wasn't picked up - restart!

### Issue: `Connection refused on port 8085`

**Check:**
1. Is AlertCaseService actually started?
   ```bash
   # Should see: "Started AlertCaseServiceApplication in X seconds"
   ```

2. Is it on the right port?
   ```properties
   # Check AlertCaseService/application.yml
   server:
     port: 8085
   ```

3. Is there a firewall blocking the connection?
   ```bash
   # Try pinging localhost
   ping localhost
   ```

### Issue: `Alerts not appearing in database`

**Check:**
1. Check AlertCaseService logs for ANY errors during processing:
   ```
   Error processing fraud alert
   ```

2. Verify database connection:
   ```properties
   # AlertCaseService/application.yml should have MySQL config
   datasource:
     url: jdbc:mysql://localhost:3306/alert_case_db
   ```

3. Check if tables exist:
   ```sql
   SELECT * FROM alert;
   SELECT * FROM case_entity;
   ```

4. Check the endpoint is correct:
   - enrichmentService calls: `http://localhost:8085/api/investigation/ingest-fraud-alert`
   - AlertCaseService has: `POST /api/investigation/ingest-fraud-alert`

---

## Database Query to Check Results

### After sending a flagged/terminated transaction:

```sql
-- Check if alert was created
SELECT * FROM alert WHERE gemini_decision = 'terminated' ORDER BY created_at DESC LIMIT 1;

-- Check if case was created
SELECT * FROM case_entity WHERE gemini_decision = 'terminated' ORDER BY created_at DESC LIMIT 1;

-- Check complete flow
SELECT 
    a.alert_id,
    a.gemini_decision,
    a.risk_score,
    c.case_id,
    c.case_status,
    c.amount,
    c.customer_name
FROM alert a
LEFT JOIN case_entity c ON a.alert_id = c.alert_id
WHERE a.created_at > NOW() - INTERVAL 1 HOUR
ORDER BY a.created_at DESC;
```

---

## Configuration Summary

### enrichmentService/src/main/resources/application.properties
```properties
spring.application.name=enrichmentService
server.port=8010
logging.level.com.bankguard.enrichmentservice=DEBUG
external.alertcase-service.url=http://localhost:8085  ← CRITICAL!
```

### AlertCaseService/src/main/resources/application.yml
```yaml
server:
  port: 8085  ← Must match enrichmentService config
  
spring:
  datasource:
    url: jdbc:mysql://localhost:3306/alert_case_db
```

---

## Expected Database Schema

### Alert Table (new columns)
```sql
ALTER TABLE alert ADD COLUMN gemini_decision VARCHAR(20);
ALTER TABLE alert ADD COLUMN risk_score DECIMAL(5,2);
ALTER TABLE alert ADD COLUMN reason TEXT;
ALTER TABLE alert ADD COLUMN transaction_id BIGINT;
ALTER TABLE alert ADD COLUMN customer_id BIGINT;
```

### Case Entity Table (new columns)
```sql
ALTER TABLE case_entity ADD COLUMN risk_score DECIMAL(5,2);
ALTER TABLE case_entity ADD COLUMN gemini_decision VARCHAR(20);
ALTER TABLE case_entity ADD COLUMN transaction_id BIGINT;
ALTER TABLE case_entity ADD COLUMN amount DECIMAL(15,2);
ALTER TABLE case_entity ADD COLUMN customer_name VARCHAR(100);
ALTER TABLE case_entity ADD COLUMN customer_balance DECIMAL(15,2);
```

---

## Success Criteria Checklist

After running a flagged/terminated transaction:

- [ ] enrichmentService logs show "FRAUD DETECTED" message
- [ ] enrichmentService logs show "Successfully sent fraud alert"
- [ ] Response shows `"alertSent": true`
- [ ] AlertCaseService logs show successful receipt
- [ ] New alert created in MySQL (check alert table)
- [ ] New case created in MySQL (check case_entity table)
- [ ] Case status = "OPEN"
- [ ] Can retrieve case via `GET /api/investigation/cases/{caseId}`

---

## Quick Verification Script

Run this PowerShell to test the flow:

```powershell
# Set variables
$TRANSACTION_API = "http://localhost:8089/api/transactions"
$ALERT_API = "http://localhost:8085/api/investigation"

# Send flagged transaction
Write-Host "Sending fraudulent transaction..."
$response = curl -X POST $TRANSACTION_API `
  -H "Content-Type: application/json" `
  -d '{
    "transactionId": 999,
    "amount": 70000000,
    "city": null,
    "state": null,
    "ipAddress": null,
    "riskScore": 0,
    "receiverAccountNumber": "FRAUD",
    "customerId": 1
  }' -s

$json = $response | ConvertFrom-Json
Write-Host "Alert Sent: $($json.alertSent)"

if ($json.alertSent -eq $true) {
    Write-Host "✓ Alert sent successfully!"
    
    # Check if alert was created
    Write-Host "Checking AlertCaseService..."
    $alerts = curl "$ALERT_API/alerts" -s | ConvertFrom-Json
    Write-Host "Total alerts: $($alerts.Count)"
} else {
    Write-Host "✗ Alert failed to send!"
}
```

---

## Changes Made Summary

| File | Change |
|------|--------|
| `enrichmentService/application.properties` | Changed port 8005 → 8085 |
| `enrichmentService/AlertCaseClient.java` | Added @Slf4j logging, detailed error messages |
| `enrichmentService/EnrichmentService.java` | Added @Slf4j, comprehensive step-by-step logging |

---

**All integration is now complete and ready for testing!** 🚀

If you still see `alertSent: false`, check the logs - they will clearly show where it's failing.
