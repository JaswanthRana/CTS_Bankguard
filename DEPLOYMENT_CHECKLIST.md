# Deployment Checklist - Location Field Refactor

## Pre-Deployment Tasks

- [ ] **Backup Database**
  ```bash
  # Back up transaction service database before migration
  mysqldump -u root -p transaction_db > backup_transaction_db_$(date +%Y%m%d).sql
  ```

- [ ] **Review All Changes**
  - [ ] Read LOCATION_REFACTOR_SUMMARY.md
  - [ ] Read API_DOCUMENTATION_UPDATED.md
  - [ ] Review QUICK_REFERENCE.md

- [ ] **Code Review**
  - [ ] All 11 files have been updated
  - [ ] No references to old `location` field remain
  - [ ] All getters/setters for city and state are present

---

## Database Migration

- [ ] **Apply Migration Script**
  ```sql
  -- Run this on transaction service database
  ALTER TABLE transactions ADD COLUMN city VARCHAR(100);
  ALTER TABLE transactions ADD COLUMN state VARCHAR(2);
  
  CREATE INDEX idx_transactions_city ON transactions(city);
  CREATE INDEX idx_transactions_state ON transactions(state);
  CREATE INDEX idx_transactions_city_state ON transactions(city, state);
  ```

- [ ] **Verify Migration Success**
  ```sql
  -- Check new columns exist
  DESCRIBE transactions;
  -- Should show: city, state columns
  
  -- Check indexes created
  SHOW INDEX FROM transactions;
  -- Should show: idx_transactions_city, idx_transactions_state, idx_transactions_city_state
  ```

- [ ] **Optional: Migrate Existing Data** (if you have old location data)
  ```sql
  -- Example migration if you have data to move
  UPDATE transactions 
  SET city = SUBSTRING_INDEX(location, ',', 1),
      state = TRIM(SUBSTRING_INDEX(location, ',', -1))
  WHERE location IS NOT NULL AND city IS NULL;
  ```

---

## Service Deployment

### Step 1: Stop All Services

- [ ] Stop Transaction Service
  ```bash
  # In the terminal where service is running
  Ctrl+C
  ```

- [ ] Stop Enrichment Service
  ```bash
  # In the terminal where service is running
  Ctrl+C
  ```

- [ ] Stop Decision Engine Service
  ```bash
  # In the terminal where service is running
  Ctrl+C
  ```

### Step 2: Build Services

- [ ] Clean and build Transaction Service
  ```bash
  cd transactionService
  ./mvnw clean package
  ```

- [ ] Clean and build Enrichment Service
  ```bash
  cd enrichmentService
  ./mvnw clean package
  ```

- [ ] Clean and build Decision Engine Service
  ```bash
  cd decisionEngineService
  ./mvnw clean package
  ```

- [ ] **Verify no compilation errors** ✅

### Step 3: Start Services (in this order)

- [ ] Start Decision Engine Service (Port 7000)
  ```bash
  cd decisionEngineService
  ./mvnw spring-boot:run
  # Wait for: "Application started successfully"
  ```

- [ ] Start Enrichment Service (Port 8081)
  ```bash
  cd enrichmentService
  ./mvnw spring-boot:run
  # Wait for: "Application started successfully"
  ```

- [ ] Start Transaction Service (Port 8080)
  ```bash
  cd transactionService
  ./mvnw spring-boot:run
  # Wait for: "Application started successfully"
  ```

---

## Smoke Testing

### Test 1: Service Health Checks

- [ ] Decision Engine Service Health
  ```powershell
  Invoke-WebRequest -Uri "http://localhost:7000/api/gemini/health" -Method Get
  # Expected: {"status":"UP","service":"Gemini Decision Engine","version":"1.0.0"}
  ```

- [ ] Enrichment Service Health
  ```powershell
  Invoke-WebRequest -Uri "http://localhost:8081/api/enrich/health" -Method Get
  # Expected: {"status":"Enrichment Service is running"}
  ```

- [ ] Transaction Service Health
  ```powershell
  Invoke-WebRequest -Uri "http://localhost:8080/health" -Method Get
  # Expected: {"status":"UP"}
  ```

### Test 2: API Test with New Format

- [ ] Run test script with new city/state format
  ```powershell
  & "C:\Users\2485084\Documents\BankGaurd\test-gemini.ps1"
  ```
  
  Expected Results:
  - ✓ Request succeeds
  - ✓ Response contains city and state (not location)
  - ✓ Gemini analysis completes
  - ✓ Decision returned with status, risk score, and reason

### Test 3: Verify Database

- [ ] Check transaction data is being stored correctly
  ```sql
  SELECT transactionId, city, state FROM transactions LIMIT 5;
  # Should show city and state columns with data
  ```

- [ ] Verify indexes are working
  ```sql
  EXPLAIN SELECT * FROM transactions WHERE state = 'NY';
  # Should use idx_transactions_state or idx_transactions_city_state
  ```

---

## Post-Deployment Validation

### Logging & Monitoring

- [ ] Check service logs for errors
  - [ ] Decision Engine logs show "City:" and "State:" in prompts
  - [ ] Enrichment Service logs show city/state conversion
  - [ ] Transaction Service logs show city/state storage

- [ ] Monitor for any exceptions
  ```
  Look for keywords: city, state, location
  No "location" field not found errors should appear
  ```

### API Validation

- [ ] Test with correct format (succeeds)
  ```json
  {"city": "New York", "state": "NY"}
  ```

- [ ] Test with old format (should fail gracefully or be rejected)
  ```json
  {"location": "New York, NY"}
  ```

### Data Integrity

- [ ] Sample 10 transactions from database
  - [ ] All have city populated
  - [ ] All have state populated (2 characters)
  - [ ] No NULL values in city/state

- [ ] Test transaction flow end-to-end
  - [ ] Create new transaction with city/state
  - [ ] Enrich transaction successfully
  - [ ] Get Gemini decision successfully
  - [ ] Verify response includes city/state

---

## Rollback Plan (if needed)

If deployment fails:

1. **Stop services**
   ```bash
   Ctrl+C on all running services
   ```

2. **Restore database backup**
   ```bash
   mysql -u root -p transaction_db < backup_transaction_db_YYYYMMDD.sql
   ```

3. **Checkout previous code**
   ```bash
   git checkout HEAD~1  # Or restore from previous version
   ```

4. **Rebuild and restart services**
   ```bash
   ./mvnw clean package
   ./mvnw spring-boot:run
   ```

5. **Verify rollback**
   ```powershell
   # Test with old location format
   Invoke-WebRequest -Uri "http://localhost:7000/api/gemini/health" -Method Get
   ```

---

## Post-Deployment Documentation

- [ ] Update API documentation for clients
- [ ] Update deployment runbooks
- [ ] Notify stakeholders of format change
- [ ] Document any data migration results
- [ ] Schedule monitoring for new city/state fields

---

## Sign-Off

- [ ] **Deployed By:** _______________
- [ ] **Date:** _______________
- [ ] **All tests passed:** _______________
- [ ] **Database verified:** _______________
- [ ] **Ready for Production:** _______________

---

## Timeline Estimate

| Phase | Estimated Time |
|-------|-----------------|
| Database backup & migration | 5-10 minutes |
| Service rebuild (3 services) | 3-5 minutes per service |
| Service startup (3 services) | 1-2 minutes per service |
| Health checks | 2 minutes |
| Smoke testing | 5-10 minutes |
| Data validation | 5 minutes |
| **Total** | **~30-50 minutes** |

---

## Support Contacts

- **Database Issues:** [DBA Contact]
- **Java Compilation:** [DevOps Contact]
- **API Testing:** [QA Contact]
- **General Questions:** [Project Lead]

---

## Notes

```
Project: BankGuard Decision Engine
Update: Location Field Refactor (location → city + state)
Date: April 10, 2026
Status: Ready for Deployment
Risk Level: Low (non-breaking internal change, API format change only)
```

---

**DO NOT PROCEED UNLESS ALL PRE-DEPLOYMENT TASKS ARE COMPLETE ✓**

Good luck! 🚀
