# Complete Transaction Enrichment & Decision Engine Flow

## System Architecture

```
User/Client
    ↓
POST /api/transactions (8083)
    ↓
[Transaction Service]
- Validates customer
- Creates transaction
- Gets previous 5 transactions
    ↓
POST /api/enrich/transaction/with-decision (8000)
    ↓
[Enrichment Service]
- Enriches transaction with customer profile
- Combines city/state → "location" field
- Converts to DecisionRequest format
    ↓
POST /api/gemini/analyze-transaction (7000)
    ↓
[Decision Engine / Gemini Service]
- Analyzes transaction data
- Calculates risk score
- Makes decision (genuine/flagged/terminated)
- Returns decision with reason
    ↓
Response flows back through all services
    ↓
Returns to Client with:
- Transaction saved in database
- Enriched transaction data
- Gemini decision & risk analysis
```

---

## Service Port Configuration

| Service | Port | URL | Endpoint |
|---------|------|-----|----------|
| Transaction Service | 8083 | http://localhost:8083 | POST /api/transactions |
| Enrichment Service | 8000 | http://localhost:8000 | POST /api/enrich/transaction/with-decision |
| Decision Engine (Gemini) | 7000 | http://localhost:7000 | POST /api/gemini/analyze-transaction |

---

## Step 1: Client Creates Transaction

**Endpoint:** `POST http://localhost:8083/api/transactions`

**Request Format:**
```json
{
  "amount": 400,
  "city": "Chennai",
  "state": "Tamil Nadu",
  "ipAddress": "192.168.1.25",
  "receiverAccountNumber": "SBI9876543210",
  "customerId": 1
}
```

**Transaction Service Processing:**
1. Validates customer exists
2. Creates Transaction entity (time = NOW, riskScore = 0.0)
3. Fetches customer profile
4. Gets last 5 transactions for customer
5. Calls Enrichment Service

---

## Step 2: Enrichment Service Processing

**Internal Request (Transaction Service → Enrichment Service)**

```json
{
  "currentTransaction": {
    "amount": 400,
    "city": "Chennai",
    "state": "Tamil Nadu",
    "ipAddress": "192.168.1.25",
    "receiverAccountNumber": "SBI9876543210",
    "customerId": 1
  },
  "customer": {
    "customerId": 1,
    "name": "John Doe",
    "email": "john@example.com",
    "accountNo": "ACC123456789",
    "balance": 50000.00,
    "bankName": "BankGuard",
    "accountType": "Checking"
  },
  "previousTransactions": [
    {
      "transactionId": 5,
      "amount": 1000.00,
      "city": "Delhi",
      "state": "Delhi",
      "ipAddress": "192.168.1.20",
      "time": "2026-04-08T15:30:00",
      "riskScore": 0.05,
      "customerId": 1,
      "receiverAccountNumber": "ACC987654321"
    },
    // ... 4 more previous transactions
  ]
}
```

**Enrichment Service Transformation:**

The Enrichment Service converts the internal format (city/state) to the format expected by Gemini (location):

```json
{
  "transactionId": 1,
  "amount": 400.00,
  "location": "Chennai, Tamil Nadu",
  "time": "2026-04-10T10:15:00",
  "riskScore": 0.0,
  "customerId": 1,
  "customerName": "John Doe",
  "customerEmail": "john@example.com",
  "customerAccountNo": "ACC123456789",
  "customerBalance": 50000.00,
  "previousTransactions": [
    {
      "transactionId": 5,
      "amount": 1000.00,
      "location": "Delhi, Delhi",
      "ipAddress": "192.168.1.20",
      "time": "2026-04-08T15:30:00",
      "riskScore": 0.05,
      "customerId": 1
    },
    // ... 4 more
  ]
}
```

---

## Step 3: Decision Engine (Gemini) Analysis

**Endpoint:** `POST http://localhost:7000/api/gemini/analyze-transaction`

**Request (Sent from Enrichment Service):**
```json
{
  "transactionId": 1006,
  "amount": 20000.00,
  "location": "Tamilnadu",
  "time": "2026-04-10T10:15:00",
  "riskScore": 0,
  "customerId": 554433,
  "customerName": "Sai",
  "customerEmail": "sai@example.com",
  "customerAccountNo": "ACC123456789",
  "customerBalance": 10800.75,
  "previousTransactions": [
    {
      "transactionId": 1005,
      "amount": 50.25,
      "location": "Tamilnadu",
      "ipAddress": "106.208.12.45",
      "time": "2026-04-10T08:00:00",
      "riskScore": 0.10,
      "customerId": 554433
    },
    // ... 4 more previous transactions
  ]
}
```

**Response (From Gemini Decision Engine):**
```json
{
  "riskScore": 100.0,
  "decision": "terminated",
  "reason": "The transaction is being terminated due to multiple high-risk factors: the amount ($20,000.00) is a massive outlier compared to the customer's average transaction ($336.15), failing the amount validation check. Furthermore, the transaction exceeds the available account balance ($10,800.75), which is a definitive indicator of high risk and potential fraud."
}
```

---

## Step 4: Response Flow Back to Client

**Enrichment Service Response to Transaction Service:**
```json
{
  "enrichedTransaction": {
    "transactionId": 1,
    "amount": 400.00,
    "city": "Chennai",
    "state": "Tamil Nadu",
    "time": "2026-04-10T10:15:00",
    "riskScore": 0.0,
    "customerId": 1,
    "customerName": "John Doe",
    "customerEmail": "john@example.com",
    "customerAccountNo": "ACC123456789",
    "customerBalance": 50000.00,
    "previousTransactions": [...]
  },
  "geminiDecision": {
    "riskScore": 100.0,
    "decision": "terminated",
    "reason": "The transaction is being terminated due to..."
  }
}
```

**Final Response to Client:**
```json
{
  "transaction": {
    "transactionId": 1,
    "amount": 400.0,
    "city": "Chennai",
    "state": "Tamil Nadu",
    "ipAddress": "192.168.1.25",
    "time": "2026-04-10T10:15:00",
    "riskScore": 0.0,
    "receiverAccountNumber": "SBI9876543210",
    "customerId": 1
  },
  "enrichmentResponse": {
    "enrichedTransaction": {...},
    "geminiDecision": {
      "riskScore": 100.0,
      "decision": "terminated",
      "reason": "..."
    }
  }
}
```

---

## Key Data Transformations

### City/State → Location Conversion

The system maintains internal format as separate city/state fields, but converts to single location field when communicating with Gemini:

**Internal (Transaction & Enrichment Services):**
```json
{
  "city": "Chennai",
  "state": "Tamil Nadu"
}
```

**External (To Gemini):**
```json
{
  "location": "Chennai, Tamil Nadu"
}
```

---

## Decision Types & Meanings

| Decision | Meaning | Action |
|----------|---------|--------|
| genuine | Low risk transaction | Approve automatically |
| flagged | Medium risk transaction | Flag for manual review |
| terminated | High risk transaction | Block/Reject immediately |

---

## Complete Request/Response Examples

### Example 1: Flagged Transaction

**Request:**
```powershell
$payload = @{
    amount = 150
    city = "Bangalore"
    state = "Karnataka"
    ipAddress = "192.168.1.30"
    receiverAccountNumber = "ICICI9876543210"
    customerId = 2
} | ConvertTo-Json

Invoke-WebRequest -Uri "http://localhost:8083/api/transactions" `
    -Method Post `
    -Body $payload `
    -ContentType "application/json" `
    -UseBasicParsing
```

**Expected Response:**
```json
{
  "transaction": {
    "transactionId": 2,
    "amount": 150.0,
    "city": "Bangalore",
    "state": "Karnataka",
    ...
  },
  "enrichmentResponse": {
    "geminiDecision": {
      "riskScore": 45.5,
      "decision": "flagged",
      "reason": "Transaction location deviates from customer's typical transaction pattern. Manual review recommended."
    }
  }
}
```

---

## Error Handling

### Invalid Customer (400 Bad Request)
```json
{
  "error": "Customer not found with ID: 999"
}
```

### Service Communication Error (500 Internal Server Error)
```json
{
  "error": "Failed to create transaction: timeout contacting enrichment service"
}
```

---

## Testing Checklist

- [ ] Transaction Service running on port 8083
- [ ] Enrichment Service running on port 8000 with location field conversions
- [ ] Decision Engine (Gemini) running on port 7000
- [ ] Database connection verified
- [ ] Customer records exist in database
- [ ] Transaction creation with valid customer works
- [ ] Invalid customer returns 400 Bad Request
- [ ] Response includes both transaction and enrichment data
- [ ] Gemini decision (decision, riskScore, reason) is returned

---

**Last Updated:** 2026-04-10 10:35 UTC
**Status:** Ready for Testing
