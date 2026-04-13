# API Documentation - Updated with City & State Fields

## Updated Field Structure

The `location` field has been **replaced** with two separate fields:
- **city**: City name (e.g., "New York", "Boston")
- **state**: State abbreviation (e.g., "NY", "MA", "PA")

---

## Example JSON Payloads

### Complete Transaction Analysis Request

**Endpoint:** `POST http://localhost:7000/api/gemini/analyze-transaction`

```json
{
  "transactionId": 12345,
  "amount": 5000.00,
  "city": "New York",
  "state": "NY",
  "time": "2026-04-09T18:09:13Z",
  "riskScore": 35.0,
  "customerId": 1,
  "customerName": "John Doe",
  "customerEmail": "john@example.com",
  "customerAccountNo": "ACC123456",
  "customerBalance": 50000.00,
  "previousTransactions": [
    {
      "transactionId": 12341,
      "amount": 150.00,
      "city": "New York",
      "state": "NY",
      "ipAddress": "192.168.1.1",
      "time": "2026-04-05T15:30:00Z",
      "riskScore": 15.0,
      "customerId": 1
    },
    {
      "transactionId": 12342,
      "amount": 250.00,
      "city": "New York",
      "state": "NY",
      "ipAddress": "192.168.1.1",
      "time": "2026-04-06T10:15:00Z",
      "riskScore": 18.0,
      "customerId": 1
    },
    {
      "transactionId": 12343,
      "amount": 300.00,
      "city": "Boston",
      "state": "MA",
      "ipAddress": "192.168.1.2",
      "time": "2026-04-07T14:45:00Z",
      "riskScore": 25.0,
      "customerId": 1
    },
    {
      "transactionId": 12344,
      "amount": 2000.00,
      "city": "New York",
      "state": "NY",
      "ipAddress": "192.168.1.1",
      "time": "2026-04-08T09:20:00Z",
      "riskScore": 20.0,
      "customerId": 1
    },
    {
      "transactionId": 12345,
      "amount": 500.00,
      "city": "Philadelphia",
      "state": "PA",
      "ipAddress": "192.168.1.3",
      "time": "2026-04-08T16:00:00Z",
      "riskScore": 22.0,
      "customerId": 1
    }
  ]
}
```

### Expected Response

```json
{
  "originalRequest": {
    "transactionId": 12345,
    "amount": 5000.00,
    "city": "New York",
    "state": "NY",
    "time": "2026-04-09T18:09:13Z",
    "riskScore": 35.0,
    "customerId": 1,
    "customerName": "John Doe",
    "customerEmail": "john@example.com",
    "customerAccountNo": "ACC123456",
    "customerBalance": 50000.00,
    "previousTransactions": [...]
  },
  "updatedRiskScore": 28.5,
  "status": "genuine",
  "reason": "Transaction matches customer's historical patterns with consistent location and reasonable amount."
}
```

---

## Enrichment Service Request

**Endpoint:** `POST http://localhost:8081/api/enrich/transaction/with-decision`

```json
{
  "currentTransaction": {
    "transactionId": 12345,
    "amount": 5000.00,
    "city": "New York",
    "state": "NY",
    "ipAddress": "192.168.1.1",
    "time": "2026-04-09T18:09:13Z",
    "riskScore": 35.0,
    "customerId": 1,
    "receiverAccountNumber": "REC123456"
  },
  "customer": {
    "customerId": 1,
    "name": "John Doe",
    "email": "john@example.com",
    "accountNo": "ACC123456",
    "balance": 50000.00,
    "bankName": "BankGuard",
    "accountType": "Checking"
  },
  "previousTransactions": [
    {
      "transactionId": 12341,
      "amount": 150.00,
      "city": "New York",
      "state": "NY",
      "ipAddress": "192.168.1.1",
      "time": "2026-04-05T15:30:00Z",
      "riskScore": 15.0,
      "customerId": 1,
      "receiverAccountNumber": "REC123456"
    },
    {
      "transactionId": 12342,
      "amount": 250.00,
      "city": "New York",
      "state": "NY",
      "ipAddress": "192.168.1.1",
      "time": "2026-04-06T10:15:00Z",
      "riskScore": 18.0,
      "customerId": 1,
      "receiverAccountNumber": "REC123456"
    }
  ]
}
```

---

## Field Reference

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| transactionId | Long | Yes | Unique transaction identifier |
| amount | Double | Yes | Transaction amount in USD |
| **city** | String | Yes | City where transaction occurred |
| **state** | String | Yes | State abbreviation (2 chars, e.g., "NY") |
| time | LocalDateTime | Yes | ISO 8601 format: `2026-04-09T18:09:13Z` |
| riskScore | Double | Yes | Initial risk score (0-100) |
| customerId | Long | Yes | Customer identifier |
| customerName | String | Yes | Full customer name |
| customerEmail | String | Yes | Customer email address |
| customerAccountNo | String | Yes | Customer account number |
| customerBalance | Double | Yes | Customer account balance |
| previousTransactions | Array | Yes | Array of previous 5 transactions (or less) |

---

## Gemini API Prompt Format

The Gemini API will now receive transactions with the new format:

```
CURRENT TRANSACTION:
- Transaction ID: 12345
- Amount: $5000.00
- City: New York
- State: NY
- Time: 2026-04-09T18:09:13Z
- Initial Risk Score: 35.0

CUSTOMER PROFILE:
- Customer ID: 1
- Name: John Doe
- Email: john@example.com
- Account: ACC123456
- Balance: $50000.00

PREVIOUS 5 TRANSACTIONS:
1. Amount: $150.00, City: New York, State: NY, Time: 2026-04-05T15:30:00Z, Risk Score: 15.0
2. Amount: $250.00, City: New York, State: NY, Time: 2026-04-06T10:15:00Z, Risk Score: 18.0
3. Amount: $300.00, City: Boston, State: MA, Time: 2026-04-07T14:45:00Z, Risk Score: 25.0
...
```

---

## Database Schema Changes

### Transaction Table

**Old Schema:**
```sql
ALTER TABLE transactions ADD COLUMN location VARCHAR(255);
```

**New Schema:**
```sql
ALTER TABLE transactions ADD COLUMN city VARCHAR(100);
ALTER TABLE transactions ADD COLUMN state VARCHAR(2);
-- Optional: Remove old location column after migration
-- ALTER TABLE transactions DROP COLUMN location;
```

**Indexes Added:**
```sql
CREATE INDEX idx_transactions_city ON transactions(city);
CREATE INDEX idx_transactions_state ON transactions(state);
CREATE INDEX idx_transactions_city_state ON transactions(city, state);
```

---

## Migration Steps

1. **Stop Services**: Stop all running microservices
2. **Update Database**: Run migration script on transaction service database
3. **Deploy Updates**: Redeploy all services with updated code
4. **Test APIs**: Use updated test scripts with new city/state format
5. **Verify Data**: Check that transactions are being stored correctly

---

## Backward Compatibility Note

The old `location` field has been removed from all DTOs and entity. If you have existing code using the `location` field, you must update it to use `city` and `state` instead.

### Old Format (Deprecated)
```json
{
  "location": "New York, NY"
}
```

### New Format (Required)
```json
{
  "city": "New York",
  "state": "NY"
}
```

---

## Testing the New Format

Use the updated test script:
```powershell
& "C:\Users\2485084\Documents\BankGaurd\test-gemini.ps1"
```

The script now uses the correct city and state fields.
