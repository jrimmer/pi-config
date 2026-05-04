---
name: migration-audit
description: Audit "delete TypeScript handler / create Go handler" migration PRs for behavioral regressions. Compares deleted Next.js route handlers against new Go handlers and flags lost side effects, response contract changes, validation gaps, and authentication drift. Use for any PR that migrates API routes from TypeScript to Go, deletes frontend handlers, or replaces one backend implementation with another.
---

# Migration Audit

Audit migration PRs that delete TypeScript/Next.js route handlers and replace them with Go handlers (or any language/platform swap). The biggest risk in these PRs is not compilation — it's **behavioral regression**: side effects, response contracts, validation, and auth checks that existed in the old code and disappeared in the new code.

## Design Philosophy

- **Behavior over implementation.** The old code is the spec. Any deviation is a bug until proven otherwise.
- **Side effects are invisible in diffs.** `fetch()`, `posthog.capture()`, `Sentry.*`, `revalidatePath()`, `console.error()`, cache invalidation — these vanish in a diff that only shows the new Go code. You must read the deleted file.
- **Frontend contracts are implicit.** The TypeScript handler and the calling component are the only documentation of the response shape. Break the shape, break the UI.

## Prerequisites

- Repository checked out with both base branch and PR branch fetched
- `gh` CLI and `git` available

## Workflow

### Step 1: Identify the Migration Pair

For a migration PR, list the deleted and added files:

```bash
cd <repo>
git diff --name-status origin/main..origin/<pr-branch> | grep -E '^D|^A'
```

Map each **deleted** file to its **added** replacement:

| Deleted (TypeScript) | Added (Go) |
|---|---|
| `src/app/api/admin/settings/route.ts` | `server/internal/handlers/admin.go` |
| `src/app/api/p/[username]/[slug]/route.ts` | `server/internal/handlers/public.go` |

### Step 2: Read the Old Handler (The Spec)

Read the deleted handler from the base branch. This is your source of truth.

```bash
git show origin/main:src/app/api/admin/settings/route.ts
```

Extract:
1. **HTTP method handlers** — GET, POST, PATCH, etc. What did each do?
2. **Response shapes** — What JSON structure did each return? What status codes?
3. **Side effects** — Any `fetch()`, `posthog.capture()`, `Sentry.captureException()`, `revalidatePath()`, `console.error()`, `analytics.track()`, `log()` calls
4. **Validation** — Input validation rules, parameter checks, body schema validation
5. **Auth/ownership** — Middleware, `verifyUser()`, ownership checks, tier checks
6. **Error handling** — What status codes for what errors? Were DB errors logged?
7. **Caching** — Cache headers, `revalidatePath()`, CDN purges

### Step 3: Read the New Handler (The Candidate)

Read the new Go handler from the PR branch:

```bash
git show origin/<pr-branch>:server/internal/handlers/admin.go
```

Map the old handler's behaviors to the new handler. Use a checklist:

### Step 4: Run the Audit Checklist

#### Response Contract
- [ ] **Status codes match** — Old returned 200, new returns 200 (not 201 or 204)
- [ ] **Response JSON shape matches** — Old returned `{ users: [...] }`, new returns same shape
- [ ] **Error response format matches** — Old returned `{ error: "..." }` with 500, new does too
- [ ] **Empty-body responses documented** — If old returned 204, verify frontend doesn't read the body

#### Side Effects (The Invisible Killers)
- [ ] **Analytics events** — `posthog.capture()`, `analytics.track()`, `mixpanel.track()`
- [ ] **Error tracking** — `Sentry.captureException()`, `Sentry.captureMessage()`
- [ ] **Cache invalidation** — `revalidatePath()`, `revalidateTag()`, Redis/cache busts
- [ ] **Background fetches** — Fire-and-forget `fetch()` calls to other services
- [ ] **Logging** — Structured logging, `console.error()`, `slog.Error()`
- [ ] **Database triggers** — Anything the old handler did that the new one delegates to SQL

#### Validation
- [ ] **Input presence checks** — Required fields still checked
- [ ] **Type/format validation** — Email regex, UUID format, number ranges
- [ ] **Sanitization** — SQL injection prevention, HTML escaping
- [ ] **Rate limiting** — Old had rate limit, new has equivalent

#### Auth & Ownership
- [ ] **Authentication** — Middleware, session/token checks
- [ ] **Authorization** — Ownership, role, tier checks
- [ ] **Row-level security** — RLS policies still apply if using Supabase

#### Error Handling
- [ ] **DB errors surfaced** — Old logged/returned DB errors, new does too
- [ ] **External service errors** — Old handled Stripe/Supabase/OpenAI failures gracefully
- [ ] **Timeouts** — Old had timeouts, new does too (e.g., `http.Client` with timeout)

### Step 5: Check Frontend Callers

The frontend component is the consumer of the API. Even if the Go handler is "correct", it can break the UI.

```bash
cd <repo>
grep -rn "api/admin/users\|api/projects/.*/export\|api/coach" src/components/ src/lib/ src/app/ \
  --include="*.ts" --include="*.tsx"
```

Read each caller and verify:
- It destructures the response the same way the new handler returns it
- It handles the same status codes
- It doesn't rely on a field that no longer exists

### Step 6: Check the Ticket

If the PR references a Linear/GitHub ticket, read it:

```bash
linear issues get TR-412     # or linear-cli issues get TR-412
gh issue view <number> --json title,body
```

Verify the PR actually fulfills the ticket's acceptance criteria, not just the parts that were easy to migrate.

### Step 7: Report Findings

Structure each finding as:

```markdown
### N. <Concise title>

**Lost behavior:** <what the old handler did>

**Current code:** <snippet from new handler>

**Impact:** <what breaks or degrades>

**Fix:** <specific recommendation>
```

Post via `gh pr review --comment --body-file`.

## Example Findings

| Finding | Old Handler | New Handler | Impact |
|---|---|---|---|
| PostHog event lost | `posthog.capture("portfolio_viewed")` | None | Portfolio views drop to zero in analytics |
| Response shape break | `return NextResponse.json({ users: data })` | `JSON(w, 200, users)` | UI shows "No users found" |
| Status code break | `return new NextResponse(null, { status: 204 })` | `w.WriteHeader(204)` | Same, but if old Go returned body, consumers break |
| Validation weakened | Zod schema with email regex | `strings.Contains(email, "@")` | `"a@b"` accepted as valid |
| Timeout lost | `fetch(url, { signal: AbortSignal.timeout(10000) })` | `http.DefaultClient.Do(req)` | Request hangs indefinitely |
| Cache header lost | `headers.set("Cache-Control", "max-age=60")` | No cache headers | Response not cached, or over-cached |

## Anti-Patterns to Avoid

- ❌ Only reading the diff — side effects don't appear in diffs
- ❌ Only reading the new code — you can't know what's missing without the old code
- ❌ Assuming "the Go version is better" — correctness beats performance
- ❌ Not checking frontend callers — the API exists to serve the UI
