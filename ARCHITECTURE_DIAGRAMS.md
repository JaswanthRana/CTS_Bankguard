# Integration Architecture & Sequence Diagrams

## System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           COMPLETE INTEGRATION FLOW                         │
└─────────────────────────────────────────────────────────────────────────────┘

                          ┌──────────────────────┐
                          │   External System    │
                          │  (Enrichment Service)│
                          └──────────┬───────────┘
                                     │
                        ┌────────────┴────────────┐
                        │ AlertCasePayload        │
                        │ (Fraud Alert Data)      │
                        └────────────┬────────────┘
                                     │
                                     ▼
        ┌────────────────────────────────────────────────────┐
        │      AlertCaseService                              │
        │      Port: 8085                                    │
        │                                                    │
        │  ┌─────────────────────────────────────────────┐  │
        │  │ AlertCaseController                         │  │
        │  │ POST /api/investigation/ingest-fraud-alert  │  │
        │  └──────────────────┬──────────────────────────┘  │
        │                     │                             │
        │                     ▼                             │
        │  ┌─────────────────────────────────────────────┐  │
        │  │ FraudInvestigationService                   │  │
        │  │ - processAlertCasePayload()                 │  │
        │  │ - Store Alert (alert table)                 │  │
        │  │ - Store Case (case_entity table)            │  │
        │  │ - Store/Retrieve Customer                   │  │
        │  │ - Build ReportingRequest                    │  │
        │  │ - Call ReportingClient.sendToReporting()    │  │
        │  └──────────────────┬──────────────────────────┘  │
        │                     │                             │
        │                     ▼                             │
        │  ┌─────────────────────────────────────────────┐  │
        │  │ ReportingClient                             │  │
        │  │ - Uses WebClient (HTTP Client)              │  │
        │  │ - POSTs ReportingRequest DTO                │  │
        │  │ - Handles success/error responses           │  │
        │  │ - Blocks until response received            │  │
        │  └──────────────────┬──────────────────────────┘  │
        │                     │                             │
        │  ┌─────────────────────────────────────────────┐  │
        │  │ AppConfig                                   │  │
        │  │ - Provides WebClient Bean                   │  │
        │  │ - Provides RestTemplate Bean                │  │
        │  └─────────────────────────────────────────────┘  │
        │                     │                             │
        │                     │ WebClient.post()            │
        │                     │ URI: http://localhost:      │
        │                     │      8088/sar/ingest-report │
        │                     │ Body: ReportingRequest      │
        │                     ▼                             │
        ├────────────────────────────────────────────────────┤
        │ Database: alert_case_db                            │
        │ - alert (caseId, customerId, riskScore, ...)       │
        │ - case_entity (caseId, alertId, status, ...)       │
        │ - case_customer (customerId, ...)                  │
        └────────────────────────────────────────────────────┘
                                     │
                                     │ HTTP POST
                                     │ ReportingRequest JSON
                                     │
                                     ▼
        ┌────────────────────────────────────────────────────┐
        │      sarReport (Reporting Service)                 │
        │      Port: 8088                                    │
        │                                                    │
        │  ┌─────────────────────────────────────────────┐  │
        │  │ SarController                               │  │
        │  │ POST /sar/ingest-report  ◄── Receives      │  │
        │  │ ingestReportingRequest()                    │  │
        │  └──────────────────┬──────────────────────────┘  │
        │                     │                             │
        │                     ▼                             │
        │  ┌─────────────────────────────────────────────┐  │
        │  │ SarService                                  │  │
        │  │ - processReportingRequest()                 │  │
        │  │ - Convert DTO to Entity                     │  │
        │  │ - Map all fields:                           │  │
        │  │   • caseId → caseId                         │  │
        │  │   • customerId → customerId                 │  │
        │  │   • status → status                         │  │
        │  │   • riskScore → riskScore                   │  │
        │  │   • reason → reason                         │  │
        │  │   • transactionId → transactionId           │  │
        │  │   • amount → amount                         │  │
        │  │   • customerName → customerName             │  │
        │  │   • Date.now() → localDate                  │  │
        │  │ - Save to database                          │  │
        │  │ - Return SarReport (HTTP 201)               │  │
        │  └──────────────────┬──────────────────────────┘  │
        │                     │                             │
        │                     ▼                             │
        │  ┌─────────────────────────────────────────────┐  │
        │  │ SarRepository                               │  │
        │  │ - JPA Repository                            │  │
        │  │ - Persists to database                      │  │
        │  └─────────────────────────────────────────────┘  │
        │                     │                             │
        ├────────────────────┼────────────────────────────────┤
        │ Database: report   │                                │
        │ - sar_report       │ Saved SarReport               │
        │   (sarId, caseId,  │ {                             │
        │    customerId,     │   sarId: 1,                   │
        │    status,         │   caseId: "CAS-XXX",          │
        │    riskScore,      │   transactionId: 123456,      │
        │    reason,         │   amount: 5000.00,            │
        │    transactionId,  │   ...                         │
        │    amount,         │ }                             │
        │    customerName,   │                               │
        │    localDate, ...) │                               │
        │                    ▼                               │
        │            HTTP 201 Created                        │
        │            {SarReport entity}                      │
        └────────────────────────────────────────────────────┘
                                     │
                                     │ Response sent back
                                     │ to AlertCaseService
                                     │
        ┌────────────────────────────▼────────────────────────┐
        │ AlertCaseService                                    │
        │ ✓ Logs success message                              │
        │ ✓ Completes transaction                             │
        │ ✓ Returns HTTP 200 OK to original caller            │
        └─────────────────────────────────────────────────────┘
```

---

## Data Flow Sequence Diagram

```
External System     AlertCaseService    ReportingClient    sarReport
      │                  │                    │                  │
      │                  │                    │                  │
      │─POST Alert────────────────────────────────────────────────>│
      │ AlertCasePayload │                    │                  │
      │                  │                    │                  │
      │                  │─Process Locally──────────────────────│
      │                  │ ✓ Save Alert                       │
      │                  │ ✓ Save Case                        │
      │                  │ ✓ Save/Retrieve Customer           │
      │                  │ ✓ Build ReportingRequest           │
      │                  │<─Complete────────────────────────│
      │                  │                    │                  │
      │                  │─Send ReportingReq─────────────────────>│
      │                  │    (WebClient)     │                  │
      │                  │                    │                  │
      │                  │                    │─Process────────┐ │
      │                  │                    │ ✓ Convert DTO │ │
      │                  │                    │ ✓ Save to DB  │ │
      │                  │                    │<────────────────┤ │
      │                  │                    │                  │
      │                  │<─HTTP 201 + Entity─────────────────────│
      │                  │                    │                  │
      │<─HTTP 200 OK────────────────────────────────────────────│
      │                  │                    │                  │
      │                  │                    │                  │
```

---

## Class Diagram

```
┌──────────────────────────────────────────────────────────────────────┐
│                       AlertCaseService                               │
└──────────────────────────────────────────────────────────────────────┘

AlertCaseController
  - ingestFraudAlert(AlertCasePayload payload): ResponseEntity<Void>
                   │
                   ▼
FraudInvestigationService
  - processAlertCasePayload(AlertCasePayload payload): void
                   │
                   ├─► AlertRepository.save(Alert)
                   ├─► CaseRepository.save(CaseEntity)
                   ├─► CaseCustomerRepository.save/findById(CaseCustomer)
                   │
                   └─► ReportingClient.sendToReporting(ReportingRequest)
                                       │
                                       ▼
                       ReportingClient (WebClient)
                       - sendToReporting(ReportingRequest): void
                       - Uses: WebClient
                       - POST to: ${external.reporting-service.url}
                       - Payload: ReportingRequest (DTO)


┌──────────────────────────────────────────────────────────────────────┐
│                           sarReport                                   │
└──────────────────────────────────────────────────────────────────────┘

SarController
  - ingestReportingRequest(ReportingRequest req): ResponseEntity<SarReport>
                   │
                   ▼
SarService
  - processReportingRequest(ReportingRequest): SarReport
                   │
                   ├─ Create: SarReport entity
                   ├─ Map fields from ReportingRequest
                   │  • caseId
                   │  • customerId
                   │  • status
                   │  • riskScore
                   │  • reason
                   │  • transactionId
                   │  • amount
                   │  • customerName
                   │  • localDate (Date.now())
                   │
                   └─► SarRepository.save(SarReport): SarReport
```

---

## Request Response Flow

### Request Details

```
HTTP POST /api/investigation/ingest-fraud-alert
Host: localhost:8085
Content-Type: application/json

{
  "decisionStatus": "flagged",
  "geminiRiskScore": 85.0,
  "transactionId": 123456,
  "amount": 5000.00,
  "customerName": "John Doe",
  "geminiDecision": {
    "decision": "fraud"
  }
}

Response:
HTTP/1.1 200 OK
```

---

### WebClient Request (AlertCaseService → sarReport)

```
HTTP POST /sar/ingest-report
Host: localhost:8088
Content-Type: application/json

{
  "caseId": "CAS-550e8400-e29b-41d4-a716-446655440000",
  "customerId": "1713001234567",
  "status": "OPEN",
  "riskScore": 85.0,
  "reason": "Fraud Alert: flagged",
  "geminiDecision": "flagged",
  "transactionId": 123456,
  "amount": 5000.0,
  "customerName": "John Doe",
  "geminiReason": "Fraud Alert: flagged",
  "customerPayload": null
}

Response:
HTTP/1.1 201 Created
Content-Type: application/json

{
  "sarId": 1,
  "localDate": "2026-04-13T10:30:45.123Z",
  "caseId": "CAS-550e8400-e29b-41d4-a716-446655440000",
  "customerId": "1713001234567",
  "status": "OPEN",
  "riskScore": 85.0,
  "reason": "Fraud Alert: flagged",
  "transactionId": 123456,
  "amount": 5000.0,
  "city": null,
  "state": null,
  "time": null,
  "customerName": "John Doe",
  "customerEmail": null,
  "customerAccountNo": null
}
```

---

## Database Schema Relationship

```
AlertCaseService Database (alert_case_db)    sarReport Database (report)
┌────────────────────────────────────┐       ┌─────────────────────────┐
│          alert                     │       │      sar_report         │
├────────────────────────────────────┤       ├─────────────────────────┤
│ PK  alertId                        │       │ PK  sarId (auto)        │
│     severity                       │       │     caseId              │
│     geminiDecision                 │       │     customerId          │
│     riskScore                      │       │     status              │
│     reason                         │       │     riskScore           │
│     transactionId                  │       │     reason              │
│     customerId (FK)                │       │     transactionId       │
│     createdAt                      │       │     amount              │
│                                    │       │     customerName        │
│          ↑ references               │       │     localDate           │
│                                    │       │     city                │
│          case_entity               │       │     state               │
│  ┌─────────────────────────┐      │       │     customerEmail       │
│  │ PK caseId               │      │       │     customerAccountNo   │
│  │    alertId (FK to alert)│◄─────┼──────└─────────────────────────┘
│  │    caseStatus           │      │
│  │    reason               │      │
│  │    riskScore            │      │  (One-way relationship:
│  │    geminiDecision       │      │   AlertCase stores locally,
│  │    transactionId        │      │   sarReport stores copy of
│  │    amount               │      │   data from ReportingRequest)
│  │    customerName         │      │
│  │    customerId (FK)      │      │
│  │    createdAt            │      │
│  │    customer (FK)        │      │
│  └──────────────┬──────────┘      │
│                 │                 │
│        case_customer              │
│  ┌─────────────────────────┐      │
│  │ PK customerId           │      │
│  │    (other fields...)    │      │
│  └─────────────────────────┘      │
└────────────────────────────────────┘
```

---

## Configuration & Port Mapping

```
┌─────────────────────────────────────────────────────┐
│         Service Configuration Summary               │
├─────────────────────────────────────────────────────┤
│                                                     │
│  AlertCaseService                                   │
│  ├─ Port: 8085                                      │
│  ├─ Context Path: /api/investigation               │
│  ├─ Database: alert_case_db (localhost:3306)        │
│  ├─ WebClient Target:                              │
│  │  http://localhost:8088/sar/ingest-report        │
│  └─ Configuration File: application.yml             │
│                                                     │
│  sarReport                                          │
│  ├─ Port: 8088                                      │
│  ├─ Context Path: /sar                             │
│  ├─ Database: report (localhost:3306)               │
│  ├─ Receives from: http://localhost:8085           │
│  └─ Configuration File: application.properties      │
│                                                     │
│  MySQL Databases                                    │
│  ├─ Host: localhost                                 │
│  ├─ Port: 3306                                      │
│  ├─ Username: root                                  │
│  ├─ Credentials: Rana@2004                          │
│  ├─ alert_case_db: Created by AlertCaseService     │
│  └─ report: Created by sarReport                   │
│                                                     │
└─────────────────────────────────────────────────────┘
```

---

## Error Handling Flow

```
Exception in AlertCaseService
         │
         ▼
ReportingClient.sendToReporting()
         │
         ├─ try {
         │   ├─ WebClient.post()
         │   │   └─ If error: .doOnError()
         │   │       └─ Log error
         │   │       └─ Print to stderr
         │   │
         │   └─ response.block()
         │
         └─ } catch (Exception e) {
             ├─ Log full stack trace
             ├─ Print to stderr
             └─ Continue execution
         }

Exception in sarReport
       │
       ▼
SarController.ingestReportingRequest()
       │
       ├─ try {
       │   └─ SarService.processReportingRequest()
       │       └─ If exception: throw RuntimeException
       │
       └─ } catch (Exception e) {
           ├─ Log error with stack trace
           ├─ Print to stderr
           └─ Return HTTP 500
       }
```

---

## Technology Stack

```
┌─────────────────────────────────────────────────────┐
│           Technology Stack Used                     │
├─────────────────────────────────────────────────────┤
│ Language:        Java 17                            │
│ Framework:       Spring Boot 4.0.5                  │
│ HTTP Client:     Spring WebClient (Reactive)        │
│ Data Access:     Spring Data JPA + Hibernate        │
│ Database:        MySQL 8.0                          │
│ Build Tool:      Maven                              │
│ Logging:         SLF4J with Logback                 │
│ Annotations:     Lombok (@Data, @Slf4j, etc.)      │
│ API Docs:        SpringDoc OpenAPI (Swagger)        │
│ Testing:         JUnit 5, Spring Test               │
└─────────────────────────────────────────────────────┘
```

---

## Summary

This integration demonstrates:
- ✅ Microservices communication via HTTP REST
- ✅ Asynchronous data forwarding with WebClient
- ✅ DTO pattern for service separation
- ✅ Proper error handling and logging
- ✅ Clean separation of concerns
- ✅ Scalable and maintainable architecture
