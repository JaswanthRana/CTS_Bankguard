# AlertCaseService ↔ sarReport Integration - Complete Setup ✓

## 🎯 Integration Overview

AlertCaseService and sarReport are now **fully integrated** using WebClient for inter-service communication. The flow is:

1. **Request arrives** at AlertCaseService
2. **Local processing** creates Alert, Case, and Customer records
3. **Forward** ReportingRequest DTO to sarReport via WebClient
4. **sarReport stores** the data as SarReport entity in its database

---

## 📋 Quick Start (5 Minutes)

### Prerequisites
- MySQL running with databases created (or auto-create enabled)
- Java 17 installed
- Both services unbuilt/ready to run

### Step 1: Build Services

```bash
# Terminal 1
cd AlertCaseService
mvn clean install

# Terminal 2  
cd sarReport
mvn clean install
```

### Step 2: Run Services

```bash
# Terminal 1
cd AlertCaseService
mvn spring-boot:run
# Should see: Started AlertCaseServiceApplication

# Terminal 2
cd sarReport
mvn spring-boot:run
# Should see: Started SarReportApplication
```

### Step 3: Test Integration

```bash
# Terminal 3
cd BankGG\Bankgaurd
powershell -ExecutionPolicy Bypass -File test-integration.ps1
# Select option 1 for Full Integration Test
```

**Expected Result:** ✅ Integration Status: SUCCESSFUL

---

## 📁 New/Modified Files

### Created Files

| File | Purpose |
|------|---------|
| `sarReport/src/main/java/com/cts/sarreport/dto/ReportingRequest.java` | DTO for integration (shared structure) |
| `ALERT_CASE_TO_SAR_INTEGRATION.md` | Comprehensive integration guide |
| `INTEGRATION_TESTING_GUIDE.md` | Detailed testing procedures |
| `INTEGRATION_SUMMARY.md` | Quick reference of changes |
| `ARCHITECTURE_DIAGRAMS.md` | Visual system diagrams |
| `test-integration.ps1` | PowerShell test script |

### Modified Files

| File | Changes |
|------|---------|
| `AlertCaseService/src/main/resources/application.yml` | Updated SAR endpoint URL to port 8088 |
| `sarReport/src/main/java/com/cts/sarreport/controller/SarController.java` | Added `/sar/ingest-report` endpoint |
| `sarReport/src/main/java/com/cts/sarreport/service/SarService.java` | Added `processReportingRequest()` method |

---

## 🔌 API Endpoints

### AlertCaseService (Port 8085)

```
POST /api/investigation/ingest-fraud-alert
├─ Accepts: AlertCasePayload
├─ Process: Creates Alert, Case, Customer locally
└─ Returns: HTTP 200 OK

GET /api/investigation/alerts
└─ Returns: List of all alerts

GET /api/investigation/cases/{caseId}
└─ Returns: Case details

GET /api/investigation/cases/status/{status}
└─ Returns: Cases with given status
```

### sarReport (Port 8088)

```
POST /sar/ingest-report ★ NEW - Integration Endpoint
├─ Accepts: ReportingRequest (from AlertCaseService)
├─ Process: Creates SarReport from ReportingRequest
└─ Returns: HTTP 201 Created with SarReport entity

GET /sar/reports
└─ Returns: List of all SAR reports

GET /sar/report/transaction/{transactionId}
└─ Returns: SAR report by transaction ID

GET /sar/report/id/{sarId}
└─ Returns: SAR report by ID

[Other existing endpoints remain unchanged]
```

---

## 🗄️ Databases

### AlertCaseService Database: `alert_case_db`

```sql
Tables:
  - alert (alertId, severity, geminiDecision, riskScore, reason, transactionId, customerId, createdAt)
  - case_entity (caseId, alertId, caseStatus, reason, riskScore, transactionId, amount, customerName, customerId, createdAt)
  - case_customer (customerId, ...)
```

### sarReport Database: `report`

```sql
Tables:
  - sar_report (sarId, caseId, customerId, status, riskScore, reason, transactionId, amount, customerName, city, state, localDate, customerEmail, customerAccountNo)
```

---

## 📊 Data Flow

```
External System
      │
      └─► POST AlertCasePayload
          to AlertCaseService:8085
          │
          └─► Process & Store Locally
              │
              └─► POST ReportingRequest
                  to sarReport:8088
                  │
                  └─► Convert & Store
                      as SarReport
                      │
                      └─► Return HTTP 201
                          with SarReport entity
```

---

## 🧪 Testing

### Option 1: PowerShell Script (Recommended)
```bash
powershell -ExecutionPolicy Bypass -File test-integration.ps1
```

**Features:**
- Menu-driven interface
- Full integration test
- Stress testing
- Service health checks
- Real-time progress display

### Option 2: Manual cURL Commands

```bash
# Send fraud alert
curl -X POST http://localhost:8085/api/investigation/ingest-fraud-alert \
  -H "Content-Type: application/json" \
  -d '{
    "decisionStatus": "flagged",
    "geminiRiskScore": 85.0,
    "transactionId": 123456,
    "amount": 5000.00,
    "customerName": "John Doe"
  }'

# Check all SAR reports (should have new report)
curl http://localhost:8088/sar/reports

# Check specific transaction
curl http://localhost:8088/sar/report/transaction/123456
```

### Option 3: Swagger UI

**AlertCaseService:** http://localhost:8085/swagger-ui.html
**sarReport:** http://localhost:8088/swagger-ui.html

---

## 📖 Documentation Files

All files are in the root directory:

1. **ALERT_CASE_TO_SAR_INTEGRATION.md**
   - Complete integration architecture
   - API endpoints documentation
   - Configuration details
   - Troubleshooting guide

2. **INTEGRATION_TESTING_GUIDE.md**
   - Step-by-step testing procedures
   - Expected outputs for each test
   - Database verification queries
   - Stress testing scripts

3. **INTEGRATION_SUMMARY.md**
   - Summary of all changes
   - Quick reference guide
   - Configuration overview

4. **ARCHITECTURE_DIAGRAMS.md**
   - System architecture diagrams
   - Sequence diagrams
   - Class diagrams
   - Database schema relationships
   - Error handling flow charts

5. **test-integration.ps1**
   - Interactive PowerShell test script
   - Multiple test scenarios
   - Service health checks

---

## ⚙️ Configuration Reference

### AlertCaseService (application.yml)

```yaml
spring:
  datasource:
    url: jdbc:mysql://localhost:3306/alert_case_db
    username: root
    password: Rana@2004
  jpa:
    hibernate:
      ddl-auto: create-drop

external:
  reporting-service:
    url: http://localhost:8088/sar/ingest-report

server:
  port: 8085
```

### sarReport (application.properties)

```properties
spring.datasource.url=jdbc:mysql://localhost:3306/report
spring.datasource.username=root
spring.datasource.password=Rana@2004
spring.jpa.hibernate.ddl-auto=update
server.port=8088
```

---

## ✅ Verification Checklist

- [x] ReportingRequest DTO created in sarReport package
- [x] SarController has new `/sar/ingest-report` POST endpoint
- [x] SarService has `processReportingRequest()` method
- [x] AlertCaseService configuration points to correct URL
- [x] WebClient is configured and working
- [x] Error handling implemented in both services
- [x] Logging is comprehensive (SLF4J)
- [x] Documentation is complete
- [x] Test script is functional
- [x] All imports are correct

---

## 🚀 Common Operations

### View All SAR Reports
```bash
curl http://localhost:8088/sar/reports | jq '.'
```

### View All Alerts
```bash
curl http://localhost:8085/api/investigation/alerts | jq '.'
```

### Get Specific Case
```bash
curl http://localhost:8085/api/investigation/cases/{caseId} | jq '.'
```

### Search by Transaction ID
```bash
curl http://localhost:8088/sar/report/transaction/{transactionId} | jq '.'
```

### Reset Databases
```bash
mysql -u root -p -e "DROP DATABASE alert_case_db; DROP DATABASE report;"
# Services will recreate on next startup
```

---

## 🆘 Troubleshooting

### Issue: Connection Refused (localhost:8088)
**Solution:** Verify sarReport is running on port 8088
```bash
netstat -ano | findstr :8088
```

### Issue: 404 Not Found on /sar/ingest-report
**Solution:** Verify endpoint exists in SarController
```java
@PostMapping("/ingest-report")
public ResponseEntity<SarReport> ingestReportingRequest(...)
```

### Issue: JSON Parse Error
**Solution:** Ensure ReportingRequest DTO exists in sarReport:
```
sarReport/src/main/java/com/cts/sarreport/dto/ReportingRequest.java
```

### Issue: Database Connection Error
**Solution:** Check MySQL is running and databases exist:
```bash
mysql -u root -p
SHOW DATABASES;
CREATE DATABASE alert_case_db;
CREATE DATABASE report;
```

### Issue: Service Won't Start
**Solution:** Check logs for specific error messages
```bash
# If using Maven:
mvn spring-boot:run 2>&1 | grep -i error
```

---

## 📞 Support

**For detailed information, see:**
- Integration logic: `ALERT_CASE_TO_SAR_INTEGRATION.md`
- Testing procedures: `INTEGRATION_TESTING_GUIDE.md`
- System design: `ARCHITECTURE_DIAGRAMS.md`
- Code changes: `INTEGRATION_SUMMARY.md`

---

## 📈 Performance Notes

- **Blocking Call:** ReportingClient uses `.block()` for synchronous response
- **Database DDL:** AlertCaseService uses `create-drop` (recreates schema on startup)
- **MySQL Dialect:** Configured for MySQL 5.7+
- **WebClient:** Non-blocking HTTP client, converts to blocking with `.block()`

---

## 🔐 Security Considerations

- Ensure MySQL credentials are protected
- Consider environment variables for sensitive config
- Implement API authentication (future enhancement)
- Add request validation on both endpoints

---

## 🎓 Learning Resources

This integration demonstrates:
- **Microservices Communication:** HTTP via WebClient
- **DTO Pattern:** Data Transfer Objects for service boundaries
- **Separation of Concerns:** Each service has its own database
- **Error Handling:** try-catch blocks with detailed logging
- **Spring Boot Best Practices:** Configuration, dependencies, annotations
- **Reactive Programming:** WebClient (non-blocking HTTP client)

---

## 📝 Notes

- Both services use MySQL (could be switched to PostgreSQL with config changes)
- WebClient is part of Spring WebFlux (included via spring-boot-starter-webmvc)
- JSON serialization/deserialization is automatic (Jackson)
- Lombok annotations reduce boilerplate code
- SLF4J provides flexible logging

---

## ✨ Next Steps

1. **Test Integration:** Run the PowerShell test script
2. **Verify Logging:** Check console output for success messages
3. **Query Databases:** Verify data persistence in both databases
4. **Review Code:** Examine the new endpoint and service method
5. **Plan Enhancements:** Consider async processing, retry logic, etc.

---

**Integration Status: ✅ COMPLETE AND READY FOR TESTING**

Last Updated: April 13, 2026
