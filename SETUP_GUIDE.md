# BankGuard Decision Engine - Setup & Deployment Guide

## Architecture Overview

The system consists of three microservices:

```
Transaction Service (Port 8080)
         ↓
Enrichment Service (Port 8081) 
         ↓
Decision Engine Service / Gemini (Port 7000)
```

### Service Responsibilities

1. **Transaction Service**: Manages customer data and transaction initiation
2. **Enrichment Service**: Enriches transactions with customer profile and previous 5 transactions
3. **Decision Engine Service**: Uses Gemini AI to analyze transactions for fraud detection

## Prerequisites

- Java 17+
- Maven 3.8+
- Google Gemini API Key

## Step-by-Step Setup

### Step 1: Get Google Gemini API Key

1. Navigate to: [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Click "Get API Key" or "Create API Key"
3. Copy your API key

### Step 2: Set Environment Variable

This is the recommended approach for production.

**Windows (PowerShell):**
```powershell
$env:GOOGLE_API_KEY = "your-api-key-here"
```

**Windows (Command Prompt):**
```cmd
set GOOGLE_API_KEY=your-api-key-here
```

**Linux/Mac:**
```bash
export GOOGLE_API_KEY=your-api-key-here
```

### Step 3: Start the Services

Navigate to each service directory and run:

**Decision Engine Service (Start First):**
```bash
cd decisionEngineService
./mvnw spring-boot:run
# Runs on http://localhost:7000
```

**Enrichment Service:**
```bash
cd enrichmentService
./mvnw spring-boot:run
# Runs on http://localhost:8081
```

**Transaction Service:**
```bash
cd transactionService
./mvnw spring-boot:run
# Runs on http://localhost:8080
```

## API Endpoints

### Decision Engine Service

#### Analyze Transaction for Fraud
```
POST /api/gemini/analyze-transaction
Content-Type: application/json

{
  "transactionId": 12345,
  "amount": 5000.00,
  "location": "New York, NY",
  "time": "2026-04-09T18:09:13.553Z",
  "riskScore": 35.0,
  "customerId": 1,
  "customerName": "John Doe",
  "customerEmail": "john@example.com",
  "customerAccountNo": "ACC123456",
  "customerBalance": 50000.00,
  "previousTransactions": [
    {
      "transactionId": 12344,
      "amount": 2000.00,
      "location": "New York, NY",
      "ipAddress": "192.168.1.1",
      "time": "2026-04-08T10:00:00Z",
      "riskScore": 20.0,
      "customerId": 1
    }
  ]
}
```

**Response:**
```json
{
  "originalRequest": { ... },
  "updatedRiskScore": 25.5,
  "status": "genuine",
  "reason": "Transaction matches customer's historical patterns with consistent location and reasonable amount"
}
```

### Enrichment Service

#### Enrich Transaction with Decision
```
POST /api/enrich/transaction/with-decision
Content-Type: application/json

{
  "currentTransaction": {
    "transactionId": 12345,
    "amount": 5000.00,
    "location": "New York, NY",
    "ipAddress": "192.168.1.1",
    "time": "2026-04-09T18:09:13.553Z",
    "riskScore": 35.0,
    "customerId": 1
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
  "previousTransactions": [ ... ]
}
```

**Response:**
```json
{
  "enrichedTransaction": {
    "transactionId": 12345,
    "amount": 5000.00,
    "location": "New York, NY",
    "time": "2026-04-09T18:09:13.553Z",
    "riskScore": 35.0,
    "customerId": 1,
    "customerName": "John Doe",
    "customerEmail": "john@example.com",
    "customerAccountNo": "ACC123456",
    "customerBalance": 50000.00,
    "previousTransactions": [ ... ]
  },
  "geminiDecision": {
    "updatedRiskScore": 25.5,
    "status": "genuine",
    "reason": "Transaction matches customer's historical patterns..."
  }
}
```

## Configuration Files

### Decision Engine Service
**File:** `decisionEngineService/src/main/resources/application.properties`

```properties
spring.application.name=gemini_test_try2
server.port=7000

# Gemini API Configuration
# Set via GOOGLE_API_KEY environment variable or below
google.api.key=${GOOGLE_API_KEY:YOUR_GOOGLE_GEMINI_API_KEY_HERE}
```

### Enrichment Service
**File:** `enrichmentService/src/main/resources/application.properties`

```properties
spring.application.name=enrichmentService
server.port=8081

# Logging Level
logging.level.root=INFO
logging.level.com.bankguard.enrichmentservice=DEBUG
```

## Decision Engine Response Levels

The Gemini API returns decisions with three possible statuses:

| Status | Description | Action |
|--------|-------------|--------|
| **genuine** | Transaction is legitimate | Process normally |
| **flagged** | Transaction is suspicious | Require additional verification |
| **terminate** | Transaction is fraudulent | Block immediately |

## Troubleshooting

### Error: "Could not resolve placeholder 'google.api.key'"
**Solution:** Set the `GOOGLE_API_KEY` environment variable or update `application.properties`

### Error: "Client creation failed"
**Solution:** Verify your API key is correct and has Gemini API access enabled

### Error: "Cannot connect to Decision Engine Service"
**Solution:** Ensure Decision Engine Service is running on port 7000

### Error: "Invalid JSON response from Gemini"
**Solution:** Check that previous transactions are properly formatted as a list

## Performance Considerations

- Previous transactions are limited to 5 most recent for optimal analysis
- Gemini API calls may take 1-5 seconds depending on load
- Consider implementing caching for frequently analyzed customer patterns

## Security Best Practices

1. **Never hardcode API keys** - Always use environment variables
2. **Use HTTPS** in production for inter-service communication
3. **Validate all inputs** before sending to Gemini API
4. **Implement rate limiting** to prevent API quota abuse
5. **Monitor API usage** to detect anomalies

## Additional Notes

- The enrichment service includes validation methods for:
  - Transaction amounts
  - Customer balance sufficiency
  - IP address format
  
- Previous transactions automatically limited to 5 most recent
- All timestamps are stored in ISO 8601 format

---

For issues or questions, check the service logs with `logging.level` set to DEBUG.
