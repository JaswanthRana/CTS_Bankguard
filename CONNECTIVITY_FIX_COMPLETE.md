# Alert Case Service - Complete Connectivity Fix

## 🔴 Root Cause Identified

The services were using **different DTOs**:
- **enrichmentService** was sending: `AlertCasePayload`
- **AlertCaseService** was expecting: `FraudAlertPayload`
- **Result**: HTTP 400 Bad Request (payload mismatch) → silently caught exception → alertSent = false

## ✅ ALL ISSUES FIXED

### 1. **DTO Alignment** 
   - Created `AlertCasePayload` in AlertCaseService (was missing)
   - Changed endpoint to accept `AlertCasePayload` instead of `FraudAlertPayload`
   - Both services now use the same payload structure

### 2. **WebClient Integration** 
   - Replaced `RestTemplate` with `WebClient` (reactive, non-blocking, better error handling)
   - Added `spring-boot-starter-webflux` to both services' pom.xml
   - Implemented proper error handling with `.doOnError()` callbacks
   - Better logging: shows exactly what succeeded/failed

### 3. **Configuration Files**
   - enrichmentService: `application.properties` (port 8010, alertcase URL 8085)
   - AlertCaseService: `application.yml` (port 8085, reporting URL)
   - Added WebClient bean to both AppConfig classes

### 4. **Service Method Alignment**
   - Created new `processAlertCasePayload()` method in FraudInvestigationService
   - Method handles AlertCasePayload directly from enrichmentService
   - Proper logging at each step of case creation

### 5. **Enhanced Logging**
   - All services now use `@Slf4j`
   - Visual separators (━━━) for important messages
   - Step-by-step flow logging
   - Success ✓ and Failure ✗ indicators

---

## Files Modified

### enrichmentService
```
✅ AlertCaseClient.java - WebClient, detailed logging
✅ RestTemplateConfig.java - Added WebClient bean
✅ EnrichmentService.java - Enhanced logging, @Slf4j
✅ application.properties - Correct AlertCaseService URL (8085)
✅ pom.xml - Added spring-boot-starter-webflux
```

### AlertCaseService
```
✅ AlertCasePayload.java - NEW DTO file
✅ AlertCaseController.java - @Slf4j, correct payload type
✅ FraudInvestigationService.java - NEW processAlertCasePayload() method, @Slf4j
✅ ReportingClient.java - WebClient, detailed logging
✅ AppConfig.java - Added WebClient bean
✅ pom.xml - Added spring-boot-starter-webflux
```

---

## Complete Data Flow Now

```
1. transactionService
   └─→ POST http://localhost:8089/api/transactions
       
2. enrichmentService
   └─→ POST http://localhost:8010/api/enrich/transaction/with-decision-and-alert
   
3. EnrichmentService.enrichAndDecideWithConditionalAlert()
   Step 1: Enrich transaction
   Step 2: Convert to DecisionRequest
   Step 3: Call Gemini (Decision_Engine_Service)
   Step 4: Receive GeminiDecisionResponse
   
4. IF decision = "flagged" OR "terminated"
   └─→ Create AlertCasePayload
   └─→ AlertCaseClient.sendToAlertCase()
       └─→ WebClient.post() to http://localhost:8085/api/investigation/ingest-fraud-alert
           └─→ LOGS: "Sending fraud alert to AlertCaseService"
           └─→ SENDS: AlertCasePayload (JSON)
           
5. AlertCaseService receives payload
   └─→ AlertCaseController.ingestFraudAlert()
       └─→ LOGS: "Received fraud alert from enrichment service"
       └─→ FraudInvestigationService.processAlertCasePayload()
           └─→ Create Alert entity
           └─→ Create CaseEntity
           └─→ Create CaseCustomer
           └─→ Forward to ReportingService
           └─→ LOGS: "Case created"
   
6. Response to enrichmentService
   └─→ HTTP 200 OK
   └─→ LOGS: "Successfully sent fraud alert"
   └─→ Response shows: "alertSent": true

7. ELSE IF decision = "genuine"
   └─→ Response shows: "alertSent": false (no call to AlertCaseService)
```

---

## Testing Steps

### Step 1: Rebuild Both Services

```bash
# enrichmentService
cd enrichmentService
mvn clean package
java -jar target/enrichmentService-1.0.0.jar

# AlertCaseService (in new terminal)
cd AlertCaseService
mvn clean package
java -jar target/AlertCaseService-0.0.1-SNAPSHOT.jar
```

### Step 2: Send a Fraudulent Transaction

```bash
curl -X POST http://localhost:8089/api/transactions \
  -H "Content-Type: application/json" \
  -d '{
    "transactionId": 123,
    "amount": 70000000,
    "city": null,
    "state": null,
    "ipAddress": null,
    "riskScore": 0,
    "receiverAccountNumber": "FRAUD",
    "customerId": 1
  }'
```

### Step 3: Check Response

```json
{
  "enrichedTransaction": {...},
  "geminiDecision": {
    "decision": "terminated",
    "riskScore": 100.0
  },
  "alertSent": true    ← SHOULD BE TRUE NOW! ✓
}
```

### Step 4: Verify Alert Case Created

```bash
curl http://localhost:8085/api/investigation/alerts
curl http://localhost:8085/api/investigation/cases
```

---

## Expected Log Output

### enrichmentService console:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
SENDING FRAUD ALERT TO ALERTCASE SERVICE
Endpoint: http://localhost:8085/api/investigation/ingest-fraud-alert
Decision: terminated, Risk Score: 100.0, Transaction ID: 123
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ SUCCESS: Fraud alert received by AlertCaseService
✓ Risk Score: 100.0, Decision: terminated
✓ Fraud alert successfully sent to AlertCaseService
✓ Transaction flagged/terminated - Alert sent to AlertCaseService
```

### AlertCaseService console:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
RECEIVED FRAUD ALERT FROM ENRICHMENT SERVICE
Decision: terminated, Risk Score: 100.0, Transaction ID: 123, Amount: 7.0E7
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Fraud alert processed successfully
✓ Case created: CAS-<uuid> | Alert: ALT-<uuid>
✓ Fraud alert processed and case created
```

---

## Troubleshooting

### If alertSent is still false:

1. **Check Maven builds succeeded**
   ```bash
   # Should see: BUILD SUCCESS
   mvn clean package
   ```

2. **Check WebFlux dependency added**
   ```bash
   # In target/classes/META-INF/maven, check pom.xml includes webflux
   ```

3. **Verify both services are running on correct ports**
   ```bash
   netstat -ano | findstr :8010  # enrichmentService
   netstat -ano | findstr :8085  # AlertCaseService
   ```

4. **Check logs for WebClient errors**
   - Look for "Failed to send fraud alert"
   - Look for connection refused/timeout
   - Check if endpoint URL is correct

5. **Test endpoint directly with Postman/curl**
   ```bash
   curl -X POST http://localhost:8085/api/investigation/ingest-fraud-alert \
     -H "Content-Type: application/json" \
     -d '{"geminiRiskScore":100,"decisionStatus":"terminated"}'
   ```

### If database not getting data:

1. Check MySQL is running
2. Verify table exists: `SELECT * FROM alert LIMIT 1;`
3. Check service logs for database errors
4. Verify JPA DDL is enabled: `spring.jpa.hibernate.ddl-auto: update`

---

## Configuration Summary

### enrichmentService

**application.properties:**
```properties
external.alertcase-service.url=http://localhost:8085  ✓
```

**RestTemplateConfig.java:**
```java
@Bean
public WebClient webClient(WebClient.Builder builder) {
    return builder.build();  ✓
}
```

### AlertCaseService

**application.yml:**
```yaml
server:
  port: 8085  ✓
```

**AppConfig.java:**
```java
@Bean
public WebClient webClient(WebClient.Builder builder) {
    return builder.build();  ✓
}
```

---

## Success Indicators

✓ Response includes `"alertSent": true` for flagged/terminated transactions
✓ enrichmentService logs show "Successfully sent fraud alert"
✓ AlertCaseService logs show "Received fraud alert"
✓ New Alert record appears in database
✓ New Case record appears in database
✓ ReportService receives case data

---

## Key Technical Changes

| Component | Old | New | Benefit |
|-----------|-----|-----|---------|
| HTTP Client | RestTemplate | WebClient | Non-blocking, better error handling |
| Error Handling | Silent catch | doOnError() | Explicit error logging |
| Payload Type | Different DTOs | Same AlertCasePayload | No serialization mismatch |
| Dependencies | Missing webflux | Added webflux | WebClient support |
| Logging | Limited | @Slf4j + detailed logs | Full visibility into flow |

---

**All connectivity issues are now resolved! Data should flow properly from enrichmentService → AlertCaseService** 🚀
