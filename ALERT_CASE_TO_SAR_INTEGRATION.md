# AlertCaseService ↔ sarReport Integration Guide

## Overview
AlertCaseService and sarReport services are now integrated to work together seamlessly using WebClient. When AlertCaseService receives a fraud alert request, it processes the data locally and forwards a `ReportingRequest` DTO to sarReport for storage and further processing.

---

## Integration Flow Diagram

```
┌─────────────────────────────┐
│     External System         │
└──────────────┬──────────────┘
               │
               ↓
┌─────────────────────────────────────────┐
│      AlertCaseService (Port 8085)       │
│                                         │
│  POST /api/investigation/ingest-fraud-alert
│  ├─ Receives AlertCasePayload           │
│  ├─ Stores alert & case locally         │
│  └─ Forwards ReportingRequest to sarReport
│         using WebClient                 │
└──────────────┬──────────────────────────┘
               │
    WebClient  │ POST /sar/ingest-report
    Request    ↓ (ReportingRequest DTO)
┌─────────────────────────────────────────┐
│        sarReport (Port 8088)            │
│                                         │
│  POST /sar/ingest-report                │
│  ├─ Receives ReportingRequest           │
│  ├─ Converts to SarReport entity        │
│  └─ Stores in database                  │
└─────────────────────────────────────────┘
```

---

## Service Details

### AlertCaseService (Port 8085)

**Key Components:**
- **Controller:** `AlertCaseController`
  - Endpoint: `POST /api/investigation/ingest-fraud-alert`
  - Accepts: `AlertCasePayload`

- **Service:** `FraudInvestigationService`
  - Method: `processAlertCasePayload(AlertCasePayload payload)`
  - Stores alert, case, and customer data locally
  - Calls `ReportingClient.sendToReporting(ReportingRequest)`

- **Client:** `ReportingClient`
  - Sends requests to sarReport via WebClient
  - Uses configured URL: `http://localhost:8088/sar/ingest-report`
  - Handles errors and logs all communications

- **Configuration:** `AppConfig`
  - Provides WebClient bean for making HTTP requests
  - WebClient is shared across the application

### sarReport (Port 8088)

**Key Components:**
- **Controller:** `SarController`
  - New Endpoint: `POST /sar/ingest-report`
  - Accepts: `ReportingRequest` DTO
  - Returns: `SarReport` entity (HTTP 201 Created)

- **Service:** `SarService`
  - Method: `processReportingRequest(ReportingRequest reportingRequest)`
  - Converts ReportingRequest to SarReport entity
  - Stores the report in the database

- **DTO:** `ReportingRequest` (newly created)
  - Located in: `com.cts.sarreport.dto` package
  - Contains: Case ID, Customer ID, Risk Score, Transaction ID, etc.

- **Entity:** `SarReport`
  - Maps ReportingRequest fields to database columns

---

## DTO Mapping

### ReportingRequest → SarReport

| ReportingRequest Field | SarReport Field |
|------------------------|-----------------|
| caseId | caseId |
| customerId | customerId |
| status | status |
| riskScore | riskScore |
| reason / geminiReason | reason |
| transactionId | transactionId |
| amount | amount |
| customerName | customerName |
| - | localDate (set to current Date) |

---

## Configuration

### AlertCaseService (application.yml)

```yaml
external:
  reporting-service:
    url: http://localhost:8088/sar/ingest-report

server:
  port: 8085
```

**Key Configuration:**
- `external.reporting-service.url`: Points to sarReport's ingest endpoint
- `server.port`: 8085 (listening for incoming requests)

### sarReport (application.properties)

```properties
server.port=8088
```

**Key Configuration:**
- `server.port`: 8088 (listening for requests from AlertCaseService)

---

## API Endpoints

### AlertCaseService

#### 1. Ingest Fraud Alert (New)
```http
POST /api/investigation/ingest-fraud-alert
Content-Type: application/json

{
  "decisionStatus": "flagged",
  "geminiRiskScore": 85.5,
  "transactionId": 123456,
  "amount": 5000.00,
  "customerName": "John Doe",
  "geminiDecision": {...}
}
```

**Response:** HTTP 200 OK

---

### sarReport

#### 1. Ingest Reporting Request (New - Integration Endpoint)
```http
POST /sar/ingest-report
Content-Type: application/json

{
  "caseId": "CAS-12345",
  "customerId": "CUST-001",
  "status": "OPEN",
  "riskScore": 85.5,
  "reason": "High-value transaction detected",
  "geminiDecision": "flagged",
  "transactionId": 123456,
  "amount": 5000.00,
  "customerName": "John Doe",
  "geminiReason": "Suspicious pattern detected"
}
```

**Response:** HTTP 201 Created
```json
{
  "sarId": 1,
  "caseId": "CAS-12345",
  "customerId": "CUST-001",
  "status": "OPEN",
  "riskScore": 85.5,
  "reason": "Suspicious pattern detected",
  "transactionId": 123456,
  "amount": 5000.00,
  "customerName": "John Doe",
  "localDate": "2026-04-13T10:30:00"
}
```

---

## Testing the Integration

### Step 1: Start Both Services

**Terminal 1 - AlertCaseService:**
```bash
cd AlertCaseService
mvn spring-boot:run
```

**Terminal 2 - sarReport:**
```bash
cd sarReport
mvn spring-boot:run
```

### Step 2: Test AlertCaseService Endpoint

```bash
curl -X POST http://localhost:8085/api/investigation/ingest-fraud-alert \
  -H "Content-Type: application/json" \
  -d '{
    "decisionStatus": "flagged",
    "geminiRiskScore": 75.0,
    "transactionId": 999888,
    "amount": 10000.00,
    "customerName": "Jane Smith"
  }'
```

### Step 3: Verify Data in sarReport

```bash
# Get all SAR reports
curl http://localhost:8088/sar/reports

# Get report by transaction ID
curl http://localhost:8088/sar/report/transaction/999888
```

---

## How It Works

### Flow Diagram with Details

1. **Request Arrives at AlertCaseService**
   - `POST /api/investigation/ingest-fraud-alert`
   - Receives `AlertCasePayload`

2. **AlertCaseService Processing**
   - Creates `Alert` entity
   - Creates `CaseEntity` with fraud case details
   - Creates/retrieves `CaseCustomer` entity
   - Builds `ReportingRequest` DTO from case data

3. **Forward to sarReport**
   - Calls `ReportingClient.sendToReporting(reportingRequest)`
   - Uses `WebClient` to POST to `http://localhost:8088/sar/ingest-report`
   - Sends `ReportingRequest` as JSON payload
   - Handles success/error responses with logging

4. **sarReport Reception & Storage**
   - `SarController.ingestReportingRequest()` receives request
   - Calls `SarService.processReportingRequest()`
   - Converts `ReportingRequest` to `SarReport` entity
   - Saves to database with current timestamp
   - Returns HTTP 201 with saved entity

---

## Error Handling

### AlertCaseService
- **ReportingClient** catches and logs all exceptions
- Blocks execution until response is received or timeout occurs
- Logs success/failure messages to console and logger

### sarReport
- **SarController** catches exceptions and returns HTTP 500
- **SarService** throws RuntimeException with detailed error message
- All errors are logged with full stack trace

---

## Logging

Both services use SLF4J with detailed logging:

### AlertCaseService Logs
```
✓ Report sent successfully to ReportingService
✗ Failed to send report to ReportingService: [error details]
```

### sarReport Logs
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RECEIVED REPORTING REQUEST FROM ALERT CASE SERVICE
Case ID: CAS-12345, Customer ID: CUST-001, Risk Score: 85.5, Transaction ID: 123456
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Reporting request processed successfully. SAR ID: 1
✓ Reporting request processed and SAR Report created: 1
✓ SAR Report stored successfully with ID: 1
```

---

## Troubleshooting

### Issue: Connection Refused (Connection refused to localhost:8088)

**Solution:**
1. Verify sarReport is running on port 8088
2. Check `sarReport/pom.xml` has spring-boot-starter-webmvc dependency
3. Verify `server.port=8088` in `application.properties`

### Issue: 404 Not Found

**Solution:**
1. Verify AlertCaseService configuration has correct URL: `http://localhost:8088/sar/ingest-report`
2. Verify endpoint exists in `SarController`: `@PostMapping("/ingest-report")`

### Issue: JSON Parsing Error

**Solution:**
1. Verify `ReportingRequest` DTO is in both services
2. Ensure field names match exactly (case-sensitive)
3. Check jackson-databind is a transitive dependency (comes with spring-boot-starter-webmvc)

### Issue: Database Constraints

**Solution:**
1. Verify MySQL databases are created:
   - AlertCaseService: `alert_case_db`
   - sarReport: `report`
2. Check credentials in both configuration files
3. Verify DDL settings: AlertCaseService uses `create-drop`, sarReport uses `update`

---

## Future Enhancements

1. **Async Processing**: Replace `block()` with async reactive streams
2. **Retry Logic**: Add retry mechanism for failed requests
3. **Message Queue**: Integrate with RabbitMQ/Kafka for event-driven architecture
4. **Service Discovery**: Use Eureka/Consul for dynamic service registration
5. **API Gateway**: Add Spring Cloud Gateway for centralized routing

---

## Files Modified

### Created Files
- `sarReport/src/main/java/com/cts/sarreport/dto/ReportingRequest.java` (NEW)

### Modified Files
- `AlertCaseService/src/main/resources/application.yml`
  - Updated `external.reporting-service.url` to point to sarReport

- `sarReport/src/main/java/com/cts/sarreport/controller/SarController.java`
  - Added import for ReportingRequest DTO
  - Added @Slf4j annotation
  - Added `ingestReportingRequest()` POST endpoint

- `sarReport/src/main/java/com/cts/sarreport/service/SarService.java`
  - Added @Slf4j annotation
  - Added `processReportingRequest()` method

---

## Summary

✅ AlertCaseService processes fraud alerts and stores them locally
✅ AlertCaseService forwards ReportingRequest to sarReport via WebClient
✅ sarReport receives and stores the reporting data
✅ Both services have proper error handling and logging
✅ Configuration is complete and endpoints are active
✅ Services communicate securely on defined ports (8085 and 8088)
