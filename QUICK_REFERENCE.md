# Quick Reference - City & State Fields

## Use This JSON Format (New)

```json
{
  "city": "New York",
  "state": "NY"
}
```

## DON'T Use This Format (Old - Removed)

```json
{
  "location": "New York, NY"
}
```

---

## State Codes (US)

| State | Code | State | Code |
|-------|------|-------|------|
| Alabama | AL | Montana | MT |
| Alaska | AK | Nebraska | NE |
| Arizona | AZ | Nevada | NV |
| Arkansas | AR | New Hampshire | NH |
| California | CA | New Jersey | NJ |
| Colorado | CO | New Mexico | NM |
| Connecticut | CT | New York | NY |
| Delaware | DE | North Carolina | NC |
| Florida | FL | North Dakota | ND |
| Georgia | GA | Ohio | OH |
| Hawaii | HI | Oklahoma | OK |
| Idaho | ID | Oregon | OR |
| Illinois | IL | Pennsylvania | PA |
| Indiana | IN | Rhode Island | RI |
| Iowa | IA | South Carolina | SC |
| Kansas | KS | South Dakota | SD |
| Kentucky | KY | Tennessee | TN |
| Louisiana | LA | Texas | TX |
| Maine | ME | Utah | UT |
| Maryland | MD | Vermont | VT |
| Massachusetts | MA | Virginia | VA |
| Michigan | MI | Washington | WA |
| Minnesota | MN | West Virginia | WV |
| Mississippi | MS | Wisconsin | WI |
| Missouri | MO | Wyoming | WY |

---

## All Updated DTOs

### Transaction Service
```java
@Entity
public class Transaction {
    private String city;    // NEW
    private String state;   // NEW
    // ... removed: private String location;
}
```

### Enrichment Service
```java
public class TransactionDTO {
    private String city;    // NEW
    private String state;   // NEW
}

public class EnrichedTransactionDTO {
    private String city;    // NEW
    private String state;   // NEW
}

public class PreviousTransactionDTO {
    private String city;    // NEW
    private String state;   // NEW
}

public class DecisionRequest {
    private String city;    // NEW
    private String state;   // NEW
}
```

### Decision Engine Service
```java
public class DecisionRequest {
    private String city;    // NEW
    private String state;   // NEW
}

public class PreviousTransactionDTO {
    private String city;    // NEW
    private String state;   // NEW
}
```

---

## All Updated Methods

### EnrichmentService
1. `enrichTransaction()` - Uses city/state
2. `convertToDecisionRequest()` - Uses city/state
3. `convertToPreviousTransactionDTO()` - Uses city/state

### GeminiService
1. `buildAnalysisPrompt()` - Displays city and state separately

---

## Database Changes

```sql
-- New columns
ALTER TABLE transactions ADD COLUMN city VARCHAR(100);
ALTER TABLE transactions ADD COLUMN state VARCHAR(2);

-- New indexes
CREATE INDEX idx_transactions_city ON transactions(city);
CREATE INDEX idx_transactions_state ON transactions(state);
```

---

## Testing Example

```powershell
# Old format (WILL FAIL)
$payload = ConvertTo-Json @{
    location = "New York, NY"
}

# New format (WILL WORK)
$payload = ConvertTo-Json @{
    city = "New York"
    state = "NY"
}
```

---

## Files That Changed

```
✓ Transaction.java (Entity)
✓ TransactionDTO.java
✓ EnrichedTransactionDTO.java
✓ PreviousTransactionDTO.java (2x)
✓ DecisionRequest.java (2x)
✓ EnrichmentService.java
✓ GeminiService.java
✓ test-gemini.ps1
✓ Database migration SQL
✓ API Documentation
✓ This guide!
```

---

## Deployment Order

1. ✅ Stop services
2. ✅ Apply database migration
3. ✅ Rebuild code
4. ✅ Restart services
5. ✅ Test with new format
6. ✅ Monitor logs

---

## Common Mistakes to Avoid

❌ Still using `location` field in requests
❌ Forgetting to update database schema
❌ Mixing old and new formats
❌ Not applying database migration
❌ Forgetting to restart services

✅ Use separate `city` and `state` fields
✅ Apply migration before code deployment
✅ Use only new format in all APIs
✅ Run database migration
✅ Restart services after changes

---

## Support

**Updated:** April 10, 2026
**Format**: Breaking change - location → city + state
**Status**: ✅ Complete and tested
