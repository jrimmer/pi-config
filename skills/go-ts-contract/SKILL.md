---
name: go-ts-contract
description: Validates API contract alignment between Go backend handlers and TypeScript frontend callers. Checks response JSON shapes, status codes, error formats, and request payloads for mismatches that cause silent UI failures. Use when migrating routes between languages, adding new endpoints, or debugging "frontend gets unexpected data" bugs.
---

# Go ↔ TypeScript Contract Validator

Validates that Go backend handlers and TypeScript frontend callers agree on:
- Response JSON shapes
- HTTP status codes
- Error response formats
- Request payload shapes

The most common silent failure in a Go/TS stack is a contract mismatch: the Go handler returns a plain array `[]User`, but the TypeScript component destructures `{ users: User[] }`, causing the UI to show an empty list with no error message.

## Design Philosophy

- **The component is the consumer, the handler is the producer.** The contract is whatever the component expects. If the handler deviates, the handler is wrong.
- **Silent failures are worse than loud failures.** A 500 error is obvious. A 200 response with the wrong shape is invisible until a user reports a blank screen.
- **Compile-time type safety does not cross the wire.** TypeScript and Go types are independent. A `User` struct in Go and a `User` interface in TS can drift without any compiler warning.

## Prerequisites

- Repository with both Go and TypeScript source
- `grep`, `sed`, `jq` (optional but helpful)

## Workflow

### Step 1: Find the Handler

Identify the Go handler for the endpoint:

```bash
cd <repo>
grep -rn '"/api/admin/users"\|"/api/projects/.*"\|"/api/coach"' server/internal/handlers/ server/internal/routes/
```

Read the handler function. Extract:
- Route path and HTTP method
- Response struct / map / slice being JSON-encoded
- Status code returned on success and on each error path
- Error response format (string, JSON object, plain text)

### Step 2: Find All Frontend Callers

Search for the API path in the frontend:

```bash
cd <repo>
grep -rn "api/admin/users\|api/projects/.*/export" src/ --include="*.ts" --include="*.tsx"
```

Read every file that calls this endpoint. Extract:
- The `apiFetch()` or `fetch()` call
- How the response is parsed (`res.json()`, `res.text()`, `res.blob()`)
- How the parsed data is destructured or typed
- What status codes the caller checks for

### Step 3: Compare Shapes

#### Response Shape Check

**Go handler:**
```go
JSON(w, http.StatusOK, users)  // users is []map[string]interface{}
```

**TypeScript caller:**
```ts
apiFetch("/api/admin/users")
  .then(res => res.json())
  .then(({ users: data, error: err }) => {
    setUsers(data || []);
  });
```

**Mismatch:** Go returns `[]User` (plain array). TS expects `{ users: User[], error?: string }`. `users` will be `undefined` → `setUsers([])` → "No users found" displayed incorrectly.

**Fix:** Wrap the Go response: `JSON(w, 200, map[string]interface{}{"users": users})`.

#### Status Code Check

**Go handler:**
```go
if err != nil {
    Error(w, http.StatusInternalServerError, "Database error")
    return
}
```

**TypeScript caller:**
```ts
const res = await apiFetch("/api/admin/users");
if (!res.ok) {
    const data = await res.json();
    setError(data.error || "Update failed");
}
```

**Match check:** Both agree that errors return JSON with an `error` field. Good.

**Mismatch example:**
```go
w.WriteHeader(http.StatusNoContent)
```

**TypeScript caller:**
```ts
const data = await res.json();  // throws on 204 NoContent
```

**Fix:** Change Go to return 200 with body, or change TS to skip `res.json()` on 204.

#### Error Format Check

**Go handler:**
```go
Error(w, 500, "Database error")  // writes: { "error": "Database error" }
```

**TypeScript caller:**
```ts
catch (e) {
    setError(e.message);  // expects error object with .message
}
```

**Mismatch:** The Go `Error()` helper returns `{ error: "..." }`, but the TS code expects a thrown Error object. If `apiFetch` throws on non-OK, this might be fine — but verify the `apiFetch` implementation.

Read `src/lib/api-fetch.ts`:
```bash
cat src/lib/api-fetch.ts
```

### Step 4: Check Request Payloads

**TypeScript caller:**
```ts
apiFetch("/api/admin/users", {
    method: "PATCH",
    body: JSON.stringify({ userId, tier: newTier }),
});
```

**Go handler:**
```go
var body struct {
    UserID string `json:"userId"`
    Tier   string `json:"tier"`
}
```

**Match check:** Field names match (`userId` → `UserID` with `json:"userId"`). Good.

**Mismatch example:**
```ts
body: JSON.stringify({ user_id, tier })  // snake_case
```

```go
var body struct {
    UserID string `json:"userId"`  // camelCase
}
```

**Fix:** Align casing. Go struct tags must match the JSON keys the frontend sends.

### Step 5: Check Query Parameters

**TypeScript caller:**
```ts
apiFetch(`/api/admin/token-usage?period=${period}`)
```

**Go handler:**
```go
period := r.URL.Query().Get("period")
switch period {
case "day", "week", "month":
default:
    period = "day"  // silent default
}
```

**Mismatch:** Invalid `period` values are silently coerced to `"day"`. The frontend might not realize it's getting wrong data.

**Fix:** Return 400 for invalid periods, or validate in the frontend before sending.

### Step 6: Check for Type Drift

When a Go struct or TypeScript interface changes, the other side must be updated:

**Go struct added field:**
```go
type User struct {
    ID    string `json:"id"`
    Email string `json:"email"`
    Tier  string `json:"tier"`  // NEW
}
```

**TypeScript interface:**
```ts
interface User {
    id: string;
    email: string;
    // tier is missing!
}
```

**Fix:** Update the TypeScript interface to include `tier`. Add a shared schema (e.g., OpenAPI or zod) if possible.

## Automated Checks

For endpoints with many callers, script the comparison:

```bash
# Extract Go response type
grep -A 10 'JSON(w, http.StatusOK' server/internal/handlers/admin.go | head -20

# Extract TS destructuring patterns
grep -A 3 'apiFetch.*api/admin/users' src/components/admin/user-manager.tsx
```

## Report Template

```markdown
### Contract Mismatch — <endpoint>

**Endpoint:** `GET /api/admin/users`

**Go returns:** `[]User` (plain array, 200 OK)

**TS expects:** `{ users: User[], error?: string }`

**Impact:** `users` destructures to `undefined` → UI shows "No users found"

**Fix:** Wrap Go response: `JSON(w, 200, map[string]interface{}{"users": users})`

---

### Status Code Mismatch — <endpoint>

**Endpoint:** `DELETE /api/projects/:id/access`

**Go returns:** `204 NoContent`

**TS expects:** `200 OK` with `{ deleted: true }` (used in `handleRevoke`)

**Impact:** `res.json()` throws on 204, caught by catch block → "Failed to revoke" shown

**Fix:** Return `200` with body, or update TS to handle 204
```

## Anti-Patterns to Avoid

- ❌ Assuming "they both use JSON, it'll be fine" — field names, nesting, and arrays vs objects all matter
- ❌ Only checking the happy path — error response shapes are just as load-bearing
- ❌ Trusting TypeScript interfaces as documentation — they can be wrong or stale
- ❌ Not checking query parameters — silent defaults hide bugs
