# Quick Reference: Service Connectivity Flow

## Decision Flow Logic

```
enrichmentService.enrichAndDecideWithConditionalAlert()
    ↓
IF geminiDecision == "flagged" OR "terminated"
    ↓
    Create AlertCasePayload
    ↓
    alertCaseClient.sendToAlertCase(alertPayload)
    ↓
    AlertCaseService: POST /api/investigation/ingest-fraud-alert
    ↓
    processFraudAlert() creates Alert & Case entities
    ↓
    Forwards to ReportService via reportingClient

ELSE IF geminiDecision == "genuine"
    ↓
    alertSent = false (NO call to AlertCaseService)
    ↓
    Return to transactionService
```

---

## New Endpoints

### enrichmentService
- **POST** `/api/enrich/transaction/with-decision-and-alert` 
  - Input: `EnrichmentRequest`
  - Output: `TransactionDecisionResponse` (includes `alertSent` boolean)
  - Contains decision-making logic

### AlertCaseService
- **POST** `/api/investigation/ingest-fraud-alert` 
  - Input: `FraudAlertPayload`
  - Output: 200 OK or 500 Error
  - Creates Alert, Case, and forwards to ReportService

---

## Key Files Modified

### enrichmentService

| File | Changes |
|------|---------|
| `AlertCaseClient.java` | NEW - Sends alerts to AlertCaseService |
| `AlertCasePayload.java` | NEW - Consolidated payload DTO |
| `EnrichmentService.java` | Added `enrichAndDecideWithConditionalAlert()` method |
| `EnrichmentController.java` | Added new endpoint |
| `TransactionDecisionResponse.java` | Added `alertSent` field |
| `application.properties` | Added `external.alertcase-service.url` config |

### AlertCaseService

| File | Changes |
|------|---------|
| `FraudAlertPayload.java` | NEW - Receives payload from enrichmentService |
| `Alert.java` | Added Gemini decision, riskScore, reason, transactionId, customerId |
| `CaseEntity.java` | Added riskScore, geminiDecision, transactionId, amount, customerName, customerBalance |
| `ReportingRequest.java` | Added transactionId, amount, customerName, geminiDecision, geminiReason |
| `FraudInvestigationService.java` | Added `processFraudAlert()` method |
| `AlertCaseController.java` | Added `/ingest-fraud-alert` endpoint |

---

## If-Else Logic Implementation

### Location: EnrichmentService.enrichAndDecideWithConditionalAlert()

```java
// Get Gemini decision
GeminiDecisionResponse geminiDecision = getGeminiDecision(decisionRequest);

// Conditional routing
String decision = geminiDecision.getDecision();
if ("flagged".equalsIgnoreCase(decision) || 
    "terminated".equalsIgnoreCase(decision)) {
    
    // CREATE ALERT - Send to AlertCaseService
    AlertCasePayload alertPayload = new AlertCasePayload();
    alertPayload.setEnrichedTransaction(enrichedTransaction);
    alertPayload.setDecisionRequest(decisionRequest);
    alertPayload.setGeminiDecision(geminiDecision);
    alertPayload.setDecisionStatus(decision);
    
    alertCaseClient.sendToAlertCase(alertPayload);
    response.setAlertSent(true);
    
} else {
    // GENUINE TRANSACTION - No alert
    response.setAlertSent(false);
}
```

---

## Data Stored in AlertCaseService

### Alert Entity Fields
- `alertId` - Unique alert identifier
- `severity` - HIGH/MEDIUM/LOW (based on riskScore)
- `createdAt` - Timestamp
- `geminiDecision` - "flagged" or "terminated"
- `riskScore` - Gemini risk score
- `reason` - Gemini analysis reason
- `transactionId` - Linked to transaction
- `customerId` - Linked to customer

### CaseEntity Fields  
- `caseId` - Unique case identifier
- `alertId` - Links to Alert
- `caseStatus` - "OPEN" (initially)
- `reason` - Detailed reason
- `riskScore` - Crime risk score
- `geminiDecision` - Decision type
- `transactionId` - For reference
- `amount` - Transaction value
- `customerName` - For quick identification
- `customerBalance` - Context data
- `customer` - Foreign key to CaseCustomer

---

## Configuration Checklist

- [ ] enrichmentService has `external.alertcase-service.url=http://localhost:8005`
- [ ] AlertCaseService is running on port 8005
- [ ] Decision_Engine_Service is accessible to enrichmentService
- [ ] ReportService URL is configured in AlertCaseService
- [ ] Database migrations applied for new Alert/Case fields
- [ ] RestTemplate is configured as @Bean in both services

---

## Testing Checklist

1. **Test Flagged Transaction**
   - Send transaction with high risk score
   - Verify Gemini returns "flagged"
   - Check AlertCaseService received alert
   - Verify Alert and Case entities created
   - Check ReportService received forward request

2. **Test Genuine Transaction**
   - Send transaction with low risk score
   - Verify Gemini returns "genuine"
   - Verify AlertCaseService NOT called
   - Response should have `alertSent = false`

3. **Test AlertCaseService Unavailable**
   - Stop AlertCaseService
   - Send flagged transaction
   - Verify enrichmentService gracefully handles error
   - Check error log message

4. **Test ReportService Integration**
   - Verify ReportingRequest contains all fields
   - Check ReportService creates compliance report
   - Verify case can be queried via `/api/investigation/cases/{caseId}`

---

## API Call Examples

### Start Fraud Detection Flow
```bash
curl -X POST http://localhost:8010/api/enrich/transaction/with-decision-and-alert \
  -H "Content-Type: application/json" \
  -d '{
    "currentTransaction": {...},
    "customer": {...},
    "previousTransactions": [...]
  }'
```

### Query Fraud Cases
```bash
# Get all cases
curl http://localhost:8005/api/investigation/cases

# Get specific case
curl http://localhost:8005/api/investigation/cases/CAS-<uuid>

# Get cases by status
curl http://localhost:8005/api/investigation/cases/status/OPEN

# Get customer cases
curl http://localhost:8005/api/investigation/customers/{customerId}/cases
```

---

## Database Schema Notes

### New columns needed:

**Alert table:**
- `gemini_decision` VARCHAR(20)
- `risk_score` DECIMAL(5,2)
- `reason` TEXT
- `transaction_id` BIGINT
- `customer_id` BIGINT

**Case table:**
- `risk_score` DECIMAL(5,2)
- `gemini_decision` VARCHAR(20)
- `transaction_id` BIGINT
- `amount` DECIMAL(15,2)
- `customer_name` VARCHAR(100)
- `customer_balance` DECIMAL(15,2)

---

## Error Codes & Solutions

| Issue | Solution |
|-------|----------|
| 404 AlertCaseService | Check URL in application.properties |
| 500 Gemini response error | Verify Decision_Engine_Service is accessible |
| Alerts not created | Check AlertCaseService logs, ensure endpoint exists |
| ReportService not getting data | Verify URL in application.yml, check ForwardingClient |
| Connection timeout | Check if AlertCaseService is overloaded, add retry logic |

