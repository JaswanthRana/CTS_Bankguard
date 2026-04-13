# Service Connectivity Implementation Summary

## Overview
Implemented conditional routing between enrichmentService and AlertCaseService based on Gemini decision outcomes. If the transaction is flagged or terminated, data flows to AlertCaseService. If genuine, no alert is sent.

---

## Flow Diagram

```
transactionService 
    ↓
enrichmentService (enriches transaction data)
    ↓
Decision_Engine_Service (gets Gemini decision)
    ↓
IF decision = "flagged" OR "terminated"
    → AlertCaseService (creates case & alert)
        ↓
        ReportService (compliance reporting)
    
ELSE IF decision = "genuine"
    → No alert sent
```

---

## Changes Made

### 1. enrichmentService - New DTOs Created

#### AlertCasePayload.java
- **Location**: `enrichmentService/src/main/java/com/bankguard/enrichmentservice/dto/`
- **Purpose**: Consolidated payload sent from enrichmentService to AlertCaseService
- **Fields**:
  - `enrichedTransaction` - EnrichedTransactionDTO with customer & transaction data
  - `decisionRequest` - DecisionRequest sent to Gemini
  - `geminiDecision` - GeminiDecisionResponse (risk score, decision, reason)
  - `decisionStatus` - "flagged" or "terminated"

#### TransactionDecisionResponse.java (UPDATED)
- **Added Field**: `alertSent` (boolean) - indicates if alert was sent to AlertCaseService
- Helps the client know whether AlertCaseService was triggered

### 2. enrichmentService - New Client Created

#### AlertCaseClient.java
- **Location**: `enrichmentService/src/main/java/com/bankguard/enrichmentservice/client/`
- **Functionality**:
  - Sends AlertCasePayload to AlertCaseService via `POST /api/investigation/ingest-fraud-alert`
  - Gracefully handles connection failures without breaking the chain
  - Uses configurable AlertCaseService URL: `external.alertcase-service.url`

### 3. enrichmentService - Service Layer Updated

#### EnrichmentService.java (UPDATED)
- **Added Dependency**: `AlertCaseClient` autowired
- **New Method**: `enrichAndDecideWithConditionalAlert(EnrichmentRequest)`
  - **Logic Flow**:
    1. Enriches transaction (adds customer info, previous 5 transactions)
    2. Converts to DecisionRequest format for Gemini
    3. Gets Gemini decision (genuine/flagged/terminated)
    4. **IF** decision is "flagged" or "terminated":
       - Creates AlertCasePayload
       - Sends to AlertCaseService
       - Sets `alertSent = true`
    5. **ELSE** (genuine):
       - Sets `alertSent = false`
    6. Returns TransactionDecisionResponse with decision details

### 4. enrichmentService - Controller Updated

#### EnrichmentController.java (UPDATED)
- **New Endpoint**: `POST /api/enrich/transaction/with-decision-and-alert`
  - Calls `enrichAndDecideWithConditionalAlert()` in service
  - Returns TransactionDecisionResponse with alertSent flag
  - Handles all errors gracefully

### 5. enrichmentService - Configuration Updated

#### application.properties (UPDATED)
- **Added Property**: `external.alertcase-service.url=http://localhost:8005`
- Configurable endpoint for AlertCaseService communication

---

## AlertCaseService Changes

### 1. New DTOs Created

#### FraudAlertPayload.java
- **Location**: `AlertCaseService/src/main/java/com/cts/AlertCaseService/dto/`
- **Purpose**: Receives consolidated fraud alert from enrichmentService
- **Fields**:
  - **Transaction Data**: transactionId, amount, city, state, time, riskScore, etc.
  - **Customer Data**: customerId, customerName, customerEmail, customerAccountNo, customerBalance
  - **Gemini Decision**: geminiRiskScore, geminiDecision, geminiReason
  - **Previous Transactions**: list of previous transactions for context
  - **Location**: Combined location string

#### ReportingRequest.java (UPDATED)
- **Added Fields**:
  - `geminiDecision` - "flagged" or "terminated"
  - `transactionId` - Linked transaction
  - `amount` - Transaction amount
  - `customerName` - Customer name
  - `geminiReason` - Detailed reason from Gemini analysis
- Provides complete context to ReportService

### 2. Entities Updated

#### Alert.java (UPDATED)
- **Added Fields**:
  - `geminiDecision` - Decision type
  - `riskScore` - Risk score from Gemini
  - `reason` - Reason for alert
  - `transactionId` - Linked transaction
  - `customerId` - Customer associated with alert

#### CaseEntity.java (UPDATED)
- **Added Fields**:
  - `riskScore` - Gemini risk score
  - `geminiDecision` - "flagged" or "terminated"
  - `transactionId` - Linked transaction
  - `amount` - Transaction amount
  - `customerName` - Customer name
  - `customerBalance` - Balance at time of transaction
- Preserves critical fraud investigation data

### 3. Service Layer Updated

#### FraudInvestigationService.java (UPDATED)
- **New Method**: `processFraudAlert(FraudAlertPayload payload)`
  - **Steps**:
    1. **Create Alert**: 
       - Generates unique alertId (ALT-UUID)
       - Sets severity based on riskScore (>80: HIGH, >60: MEDIUM, else: LOW)
       - Stores Gemini decision and reason
       - Links to transaction and customer
    2. **Create/Retrieve Customer**: 
       - Persists or retrieves CaseCustomer entity
    3. **Create Case**:
       - Generates unique caseId (CAS-UUID)
       - Links to alert and customer
       - Sets case status to "OPEN"
       - Stores transaction details for investigation
    4. **Forward to ReportService**:
       - Constructs ReportingRequest with all fraud details
       - Sends to ReportingClient for compliance reporting

- **Original Method**: `processAndForward(EnrichPayload)` 
  - Kept for backward compatibility
  - Still supports legacy EnrichPayload format

### 4. Controller Updated

#### AlertCaseController.java (UPDATED)
- **New Endpoint**: `POST /api/investigation/ingest-fraud-alert`
  - Accepts FraudAlertPayload from enrichmentService
  - Calls `processFraudAlert()` in service
  - Error handling: Returns 500 if failures occur
  - Success: Returns 200 OK

- **Original Endpoint**: `POST /api/investigation/ingest`
  - Kept for backward compatibility with EnrichPayload

---

## Data Flow Through System

### For Flagged/Terminated Transactions:

```
1. transactionService
   → POST /api/enrich/transaction/with-decision-and-alert
   → Sends EnrichmentRequest (transaction + customer + previous 5 transactions)

2. enrichmentService
   → Enriches transaction
   → Converts to DecisionRequest
   → Calls Decision_Engine_Service (Gemini)
   → Receives GeminiDecisionResponse
   → Decision = "flagged" or "terminated" → TRUE
   → Creates AlertCasePayload
   → POST to AlertCaseClient

3. AlertCaseClient
   → POST http://localhost:8005/api/investigation/ingest-fraud-alert
   → Sends AlertCasePayload

4. AlertCaseService
   → Receives FraudAlertPayload
   → Creates Alert entity (severity, Gemini decision, risk score)
   → Creates CaseEntity (OPEN status, linked to alert)
   → Creates/retrieves CaseCustomer
   → Constructs ReportingRequest
   → Forwards to ReportService via ReportingClient

5. ReportService
   → Processes fraud case for compliance and reporting
```

### For Genuine Transactions:

```
1. transactionService
   → POST /api/enrich/transaction/with-decision-and-alert
   → Sends EnrichmentRequest

2. enrichmentService
   → Enriches transaction
   → Gets Gemini decision
   → Decision = "genuine" → TRUE
   → Sets alertSent = false
   → Returns TransactionDecisionResponse
   → NO call to AlertCaseService

3. Response back to transactionService
   → enrichmentService returns with alertSent = false
   → No alert case created
   → Transaction approval/denial handled elsewhere
```

---

## Configuration Required

### enrichmentService (application.properties)
```properties
external.alertcase-service.url=http://localhost:8005
```

### AlertCaseService (application.yml)
Ensure ReportingClient is configured with:
```yaml
external:
  reporting-service:
    url: http://localhost:9000  # Or appropriate ReportService URL
```

---

## Testing Endpoints

### 1. Enrich and Route with Decision
```bash
POST http://localhost:8010/api/enrich/transaction/with-decision-and-alert
Content-Type: application/json

{
  "currentTransaction": {
    "transactionId": 1001,
    "amount": 50000,
    "city": "Mumbai",
    "state": "Maharashtra",
    "ipAddress": "192.168.1.1",
    "riskScore": 75,
    "customerId": 100,
    "receiverAccountNumber": "34567890123456"
  },
  "customer": {
    "customerId": 100,
    "name": "Raj Kumar",
    "email": "raj@bank.com",
    "accountNo": "123456789",
    "balance": 500000
  },
  "previousTransactions": []
}
```

### 2. Check Alert Cases Created
```bash
GET http://localhost:8005/api/investigation/alerts
GET http://localhost:8005/api/investigation/cases
GET http://localhost:8005/api/investigation/cases/{caseId}
```

---

## Key Improvements

1. **Conditional Routing**: Alert only for risky transactions (flagged/terminated)
2. **Rich Context**: AlertCaseService receives complete transaction, customer, and Gemini analysis data
3. **Unified Payload**: AlertCasePayload carries all needed information in one object
4. **Backward Compatible**: Old endpoints still work with EnrichPayload
5. **Error Handling**: AlertCaseClient doesn't break chain if AlertCaseService is unavailable
6. **Compliance Ready**: ReportingRequest now includes all fraud details for reporting service
7. **Investigation Data**: Case entity stores complete transaction snapshot for analyst investigation

---

## Next Steps (Optional)

1. **Add Message Queue**: Replace REST calls with Kafka/RabbitMQ for resilience
2. **Add Metrics**: Track alert sent vs. genuine transaction ratios
3. **Add Audit Logging**: Log all decision routing to audit table
4. **Add Webhook**: Let transactionService know if alert was created
5. **Database Migration**: Add new columns to Alert and CaseEntity tables

---

## Troubleshooting

### AlertCaseService Not Receiving Alerts
1. Verify `external.alertcase-service.url` in enrichmentService
2. Ensure AlertCaseService is running on port 8005
3. Check logs: Look for "Successfully sent fraud alert to AlertCaseService"

### Gemini Decision Always "genuine"
1. Verify Decision_Engine_Service is accessible
2. Check risk scores are being calculated correctly
3. Verify Gemini API is properly configured

### ReportService Not Getting Case Data
1. Verify ReportingClient URL is correct
2. Ensure ReportingRequest fields are properly mapped
3. Check AlertCaseService logs for forwarding errors
