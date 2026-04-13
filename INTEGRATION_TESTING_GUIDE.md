# Integration Testing Checklist

## Pre-Flight Checks

- [ ] MySQL is running
- [ ] Both service databases exist:
  - [ ] `alert_case_db` (for AlertCaseService)
  - [ ] `report` (for sarReport)
- [ ] Ports 8085 and 8088 are available

---

## Service Startup

### Terminal 1: Start AlertCaseService
```bash
cd AlertCaseService
mvn clean install
mvn spring-boot:run
```

**Expected Output:**
```
...
Started AlertCaseServiceApplication in X.XXX seconds
```

### Terminal 2: Start sarReport
```bash
cd sarReport
mvn clean install
mvn spring-boot:run
```

**Expected Output:**
```
...
Started SarReportApplication in X.XXX seconds
```

---

## Integration Test Flow

### Test 1: Send Fraud Alert to AlertCaseService

**Command:**
```bash
curl -X POST http://localhost:8085/api/investigation/ingest-fraud-alert \
  -H "Content-Type: application/json" \
  -d '{
    "decisionStatus": "flagged",
    "geminiRiskScore": 85.0,
    "transactionId": 123456789,
    "amount": 15000.50,
    "customerName": "John Smith",
    "geminiDecision": {"decision": "fraud"}
  }'
```

**Expected Response:**
```
HTTP 200 OK
```

**Expected Logs in AlertCaseService:**
```
RECEIVED FRAUD ALERT FROM ENRICHMENT SERVICE
Decision: flagged, Risk Score: 85.0, Transaction ID: 123456789, Amount: 15000.5
✓ Fraud alert processed successfully
✓ Case created: CAS-XXXXXXXX | Alert: ALT-XXXXXXXX
Sending report to ReportingService at: http://localhost:8088/sar/ingest-report
✓ Report sent successfully to ReportingService
✓ Successfully sent data to Reporting Service
```

**Expected Logs in sarReport:**
```
RECEIVED REPORTING REQUEST FROM ALERT CASE SERVICE
Case ID: CAS-XXXXXXXX, Customer ID: ..., Risk Score: 85.0, Transaction ID: 123456789
✓ Reporting request processed successfully. SAR ID: 1
✓ Reporting request processed and SAR Report created: 1
✓ SAR Report stored successfully with ID: 1
```

---

### Test 2: Verify Data Stored in sarReport

**Command:**
```bash
curl http://localhost:8088/sar/reports
```

**Expected Response:**
```json
[
  {
    "sarId": 1,
    "caseId": "CAS-XXXXXXXX",
    "customerId": "...",
    "status": "OPEN",
    "riskScore": 85.0,
    "reason": "...",
    "transactionId": 123456789,
    "amount": 15000.50,
    "customerName": "John Smith",
    "localDate": "2026-04-13T..."
  }
]
```

---

### Test 3: Query by Transaction ID

**Command:**
```bash
curl http://localhost:8088/sar/report/transaction/123456789
```

**Expected Response:**
```json
{
  "sarId": 1,
  "caseId": "CAS-XXXXXXXX",
  "customerId": "...",
  "status": "OPEN",
  "riskScore": 85.0,
  "reason": "...",
  "transactionId": 123456789,
  "amount": 15000.50,
  "customerName": "John Smith",
  "localDate": "2026-04-13T..."
}
```

---

### Test 4: Verify Local Storage in AlertCaseService

**Command:**
```bash
curl http://localhost:8085/api/investigation/alerts
```

**Expected Response:** List of alerts including the one just created

**Command:**
```bash
curl http://localhost:8085/api/investigation/cases/status/OPEN
```

**Expected Response:** List of cases with status OPEN

---

## Database Verification

### AlertCaseService Database (alert_case_db)

```sql
-- Connect to MySQL
mysql -u root -p

-- Use database
USE alert_case_db;

-- Check alerts table
SELECT * FROM alert;

-- Check cases table
SELECT * FROM case_entity;

-- Check customers
SELECT * FROM case_customer;
```

### sarReport Database (report)

```sql
-- Use database
USE report;

-- Check SAR reports table
SELECT * FROM sar_report;
```

---

## Stress Testing

### Multiple Fraud Alerts

```bash
for i in {1..5}; do
  curl -X POST http://localhost:8085/api/investigation/ingest-fraud-alert \
    -H "Content-Type: application/json" \
    -d "{
      \"decisionStatus\": \"flagged\",
      \"geminiRiskScore\": $((70 + RANDOM % 30)),
      \"transactionId\": $((100000000 + i)),
      \"amount\": $((5000 + RANDOM % 15000)),
      \"customerName\": \"Customer $i\"
    }"
  sleep 1
done
```

**Verify all reports are stored:**
```bash
curl http://localhost:8088/sar/reports
```

---

## Common Issues & Solutions

### Issue: Connection Refused
- **Check:** Is sarReport running on port 8088?
- **Fix:** Start sarReport first, then AlertCaseService

### Issue: 404 Not Found
- **Check:** Is endpoint `/sar/ingest-report` correct in sarReport?
- **Fix:** Verify SarController has the new POST endpoint

### Issue: JSON Parse Error
- **Check:** Are both services using the same ReportingRequest DTO?
- **Fix:** Ensure sarReport has the dto folder with ReportingRequest.java

### Issue: Database Error
- **Check:** Do both databases exist?
- **Fix:** Create databases or ensure MySQL allows auto-creation

---

## Success Criteria

✅ AlertCaseService receives fraud alert (HTTP 200)
✅ AlertCaseService logs show "Report sent successfully"
✅ sarReport logs show "Reporting request processed successfully"
✅ SAR Report is created in sarReport database
✅ Data can be queried from sarReport (HTTP 200)
✅ No errors in either service logs

---

## Cleanup

### Stop Services
```bash
# Terminal 1 & 2: Press Ctrl+C
```

### Reset Databases
```bash
mysql -u root -p
DROP DATABASE alert_case_db;
DROP DATABASE report;
```

(Services will recreate them on next startup with AlertCaseService's `create-drop` setting)
