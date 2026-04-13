# Quick Verification - CustomerPayload Fix

## 🧪 Verify the Fix in Real-Time

### Step 1: Check AlertCaseService Code
The fix is in place. Verify by checking the recent changes:

```bash
# File: AlertCaseService/src/main/java/com/cts/AlertCaseService/service/FraudInvestigationService.java
# Look for:
# ✓ processAlertCasePayload() - now extracts enrichedTransaction
# ✓ processFraudAlert() - now creates enrichedCustomerData Map
# ✓ Helper method createEnrichedDataMap()
```

### Step 2: Build and Start Services

```bash
# Terminal 1: Build AlertCaseService
cd AlertCaseService
mvn clean install
mvn spring-boot:run

# Terminal 2: Build sarReport (if not already built)
cd sarReport
mvn clean install
mvn spring-boot:run

# Wait for both services to start - you should see:
# AlertCaseService: Started AlertCaseServiceApplication in X.XXX seconds
# sarReport: Started SarReportApplication in X.XXX seconds
```

### Step 3: Send Test Fraud Alert with Enrichment Data

**Scenario A: AlertCasePayload with enrichedTransaction**
```bash
curl -X POST http://localhost:8085/api/investigation/ingest-fraud-alert \
  -H "Content-Type: application/json" \
  -d '{
    "decisionStatus": "flagged",
    "geminiRiskScore": 85.0,
    "transactionId": 555888,
    "amount": 12500.00,
    "customerName": "Alice Smith",
    "enrichedTransaction": {
      "transactionId": 555888,
      "customerId": 2001,
      "customerName": "Alice Smith",
      "city": "San Francisco",
      "state": "CA",
      "customerEmail": "alice@bank.com",
      "customerAccountNo": "SF123456789",
      "customerBalance": 75000.00,
      "amount": 12500.00,
      "riskScore": 85.0,
      "time": "2026-04-13T14:30:00"
    }
  }'
```

**Expected Response:**
```
HTTP/1.1 200 OK
```

**Expected Console Output in AlertCaseService:**
```
RECEIVED FRAUD ALERT FROM ENRICHMENT SERVICE
Decision: flagged, Risk Score: 85.0, Transaction ID: 555888, Amount: 12500.0
✓ Fraud alert processed successfully
Case created: CAS-XXXXXXXX | Alert: ALT-XXXXXXXX
Sending report to ReportingService at: http://localhost:8088/sar/ingest-report
✓ Report sent successfully to ReportingService
```

**Expected Console Output in sarReport:**
```
RECEIVED REPORTING REQUEST FROM ALERT CASE SERVICE
Case ID: CAS-XXXXXXXX, Customer ID: 2001, Risk Score: 85.0, Transaction ID: 555888
DEBUG: customerPayload present: true
DEBUG: Extracting enrichment data from customerPayload
✓ Successfully extracted enrichment data from Map payload
✓ Reporting request processed successfully. SAR ID: 1
✓ SAR Report stored successfully with ID: 1
```

### Step 4: Verify Data in sarReport Database

```bash
# Connect to MySQL
mysql -u root -p
# Password: Rana@2004

# Select database
USE report;

# Check the stored SAR report
SELECT sarId, caseId, customerId, status, city, state, 
       customerEmail, customerAccountNo, customerName, 
       transactionId, amount, localDate
FROM sar_report 
WHERE transactionId = 555888;
```

**Expected Output:**
```
+-------+-----------+------------+--------+---------------+-------+-------------------+-------------------+---------------+---------------+----------+---------------------+
| sarId | caseId    | customerId | status | city          | state | customerEmail     | customerAccountNo | customerName  | transactionId | amount   | localDate           |
+-------+-----------+------------+--------+---------------+-------+-------------------+-------------------+---------------+---------------+----------+---------------------+
|     1 | CAS-XXXXX |       2001 | OPEN   | San Francisco | CA    | alice@bank.com    | SF123456789       | Alice Smith   |        555888 |  12500.0 | 2026-04-13 14:30:xx |
+-------+-----------+------------+--------+---------------+-------+-------------------+-------------------+---------------+---------------+----------+---------------------+

✓ Row Count: 1 (Data found and complete)
✓ city: San Francisco (NOT NULL) ✓
✓ state: CA (NOT NULL) ✓
✓ customerEmail: alice@bank.com (NOT NULL) ✓
✓ customerAccountNo: SF123456789 (NOT NULL) ✓
```

---

## ✅ Verification Checklist

### Browser/Console Checks
- [ ] AlertCaseService logs show fraud alert processed
- [ ] sarReport logs show reporting request received
- [ ] sarReport logs show "customerPayload present: true"
- [ ] sarReport logs show "Successfully extracted enrichment data"
- [ ] No error messages in either service

### Database Checks
- [ ] Query returns 1 row
- [ ] city field NOT NULL (has value)
- [ ] state field NOT NULL (has value)
- [ ] customerEmail field NOT NULL (has value)
- [ ] customerAccountNo field NOT NULL (has value)
- [ ] transactionId matches (555888)
- [ ] amount is correct (12500.0)
- [ ] customerName is correct (Alice Smith)

---

## 🔍 Additional Test: Stress Test with Multiple Alerts

```bash
#!/bin/bash
# Save as test-enrichment.sh

for i in {1..5}; do
  TX_ID=$((666000 + i))
  AMOUNT=$((10000 + i * 1000))
  
  echo "Sending alert $i with Transaction ID: $TX_ID"
  
  curl -X POST http://localhost:8085/api/investigation/ingest-fraud-alert \
    -H "Content-Type: application/json" \
    -d "{
      \"decisionStatus\": \"flagged\",
      \"geminiRiskScore\": $((70 + RANDOM % 30)),
      \"transactionId\": $TX_ID,
      \"amount\": $AMOUNT,
      \"customerName\": \"Customer $i\",
      \"enrichedTransaction\": {
        \"transactionId\": $TX_ID,
        \"customerId\": $((3000 + i)),
        \"customerName\": \"Customer $i\",
        \"city\": \"City $i\",
        \"state\": \"ST$i\",
        \"customerEmail\": \"customer$i@bank.com\",
        \"customerAccountNo\": \"ACC$TX_ID\",
        \"amount\": $AMOUNT
      }
    }"
  
  sleep 1
done

echo "✓ All alerts sent. Check database for results:"
echo "SELECT COUNT(*) as total_sar_reports FROM sar_report;"
```

**Run it:**
```bash
chmod +x test-enrichment.sh
./test-enrichment.sh
```

**Then verify:**
```sql
USE report;
SELECT COUNT(*) as total_sar_reports FROM sar_report;
-- Should return: 5

SELECT * FROM sar_report 
WHERE city IS NOT NULL AND state IS NOT NULL 
ORDER BY sarId DESC LIMIT 5;
-- Should show all 5 records with enrichment data
```

---

## 🐛 Troubleshooting

### Issue: "customerPayload present: false" in logs
**Cause:** enrichedTransaction is null in AlertCasePayload  
**Solution:** Ensure you're sending `enrichedTransaction` object in the request body

### Issue: NULL values in database after comparison
**Cause:** Enrichment data not being extracted  
**Steps to debug:**
```bash
# 1. Check AlertCaseService logs for "enrichedData" message
# 2. Check sarReport logs for extraction messages
# 3. Verify WebClient actually sent the data:
curl http://localhost:8088/sar/reports | jq '.[-1]'
# Look at the last report - should have all fields populated
```

### Issue: JSON Parse Error
**Cause:** customerPayload structure mismatch  
**Solution:** Ensure enrichedTransaction has all expected fields

---

## 📊 Expected Improvements

### Before Fix ❌
```
SELECT * FROM sar_report;
city: NULL, state: NULL, customerEmail: NULL, customerAccountNo: NULL
```

### After Fix ✅
```
SELECT * FROM sar_report;
city: San Francisco, state: CA, customerEmail: alice@bank.com, customerAccountNo: SF123456789
```

---

## 🔄 Complete Data Flow Verification

### Flow Diagram
```
AlertCaseService receives AlertCasePayload
    │
    ├─ enrichedTransaction = payload.getEnrichedTransaction()
    │
    ├─ Build ReportingRequest with:
    │  └─ customerPayload = enrichedTransaction ✓ (NOW FIXED!)
    │
    └─ WebClient sends to sarReport
         │
         ↓
    sarReport receives ReportingRequest
         │
         ├─ customerPayload = EnrichedTransactionDTO ✓
         │
         ├─ extractAndMapCustomerPayload()
         │  ├─ Convert to Map using Jackson
         │  ├─ Extract city → SarReport.city ✓
         │  ├─ Extract state → SarReport.state ✓
         │  ├─ Extract customerEmail ✓
         │  └─ Extract customerAccountNo ✓
         │
         └─ Save to database with all fields populated ✓
```

---

## 🎯 Success Criteria

✅ AlertCaseService extracts enrichedTransaction  
✅ enrichedTransaction is passed as customerPayload  
✅ sarReport receives customerPayload with data  
✅ sarReport extracts all fields from customerPayload  
✅ Database has NO NULL values in enrichment fields  
✅ Console logs show successful extraction  

---

**Run this verification immediately after starting services to confirm the fix is working!**
