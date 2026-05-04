---
name: pr-review
description: Automated code review pipeline for GitHub pull requests. Fetches diffs, analyzes for correctness, security, performance, and behavioral regressions, then posts structured review comments via gh CLI. Use when asked to review a PR, review pull requests, do code review, or audit a GitHub PR.
---

# PR Review

Automated code review pipeline for GitHub pull requests. Fetches the full diff, analyzes for adverse findings across correctness, security, performance, behavioral regressions, and contract mismatches, then posts structured review comments directly to the PR via `gh pr review`.

## Design Philosophy

- **Adverse findings only.** Do not post praise, checkmarks, or "LGTM" comments. Only comment on things that could cause bugs, regressions, or maintenance issues.
- **Behavior over style.** Flag contract mismatches, lost side effects, silent error swallowing, and response shape changes before cosmetic issues.
- **Never use `--request-changes`.** The PR author is the same user as the reviewer. Always use `--comment`.
- **Bash-escape mitigation.** Write review bodies to a temp file and use `--body-file` to avoid shell escaping issues.

## Prerequisites

- `gh` CLI authenticated with access to the target repository
- Repository checked out locally with PR branches accessible (`git fetch origin`)

## Workflow

### Step 1: Discover PRs

If the user gave a PR number, use it directly. If they asked for "review my open PRs", list them:

```bash
cd <repo> && gh pr list --author @me --json number,title,headRefName,body
```

### Step 2: Fetch Diff and Metadata

For each PR to review:

```bash
cd <repo>
gh pr view <number> --json number,title,body,headRefName,baseRefName,author
gh pr diff <number>
```

Read any referenced issues or linked Linear tickets from the PR body.

### Step 2b: Fetch the Ticket/Spec

If the PR references a Linear issue (e.g., `TR-412`) or GitHub issue, read the full ticket before analyzing the code. The ticket is the acceptance criteria — the PR must be judged against it, not just against "does this code compile?"

**Linear:**
```bash
linear issues get TR-412        # or linear-cli issues get TR-412
```

**GitHub:**
```bash
gh issue view <number> --json title,body,labels,state
```

Extract the acceptance criteria, scope boundaries, and any "out of scope" notes. If the ticket is not accessible, skip this check and note it in the review.

### Step 3: Read Affected Files on Disk

Checkout the PR branch (or use `git show origin/<branch>:<path>`) to read the actual Go/TS/SQL files. The diff alone is not enough — you need the full function bodies to check error handling, response shapes, and side effects.

```bash
git fetch origin
git show origin/<branch>:server/internal/handlers/example.go
```

Also read the **deleted** files from `main` (or the base branch) to compare what behavior existed before:

```bash
git show origin/main:src/app/api/example/route.ts
```

### Step 4: Analyze

Check each of the following categories. Stop when you have 1–5 high-quality adverse findings. Do not generate low-value noise.

#### A. Correctness
- Error return values silently discarded (`_ = someCall()`)
- Nil pointer risks (dereferencing after a failed query)
- Race conditions or goroutine leaks
- SQL injection vectors (string concatenation into queries)
- Transaction rollback not deferred or ignored

#### B. Behavioral Regression (Migration PRs)
When a TypeScript handler is deleted and replaced with a Go handler, check:
- **Lost side effects:** analytics events (PostHog, Sentry), cache invalidation, background fetches, logging
- **Response shape changes:** Did the old handler return `{ users: [...] }` but the new one returns a plain array?
- **Status code changes:** 200 with body → 204 NoContent (breaks consumers)
- **Error handling softening:** Did the old handler return 400 for invalid params, but the new one silently defaults?
- **Missing validation:** Was stricter validation dropped in translation?

#### C. Security
- Auth/ownership checks missing or bypassed
- Input validation weakened
- Secrets logged or returned in responses
- CORS/cache headers changed inappropriately

#### D. Performance
- N+1 queries introduced
- Full-table scans or missing indexes
- Client-side aggregation replacing DB aggregation for large datasets
- Unbounded result sets (no `LIMIT`)
- HTTP clients without timeouts

#### E. Architecture / Maintainability
- Duplicate logic with another PR/branch
- Magic strings that should be constants
- Type safety regressions (e.g., `any` replacing a discriminated union)
- Test coverage gaps for the new code path

#### F. Ticket/Spec Conformance
Compare the PR changes against the ticket's acceptance criteria. Flag:
- **Scope creep:** Code changes that go beyond what the ticket asked for (risk: untested, unreviewed behavior entering production)
- **Missing acceptance criteria:** The ticket says "invalidate cache on update" but the PR doesn't
- **Wrong solution:** The ticket asked for server-side validation, but the PR only added client-side validation
- **Ticket contradiction:** The PR does X, but a linked dependency ticket says "do NOT do X yet"
- **Test coverage gap:** The ticket specifies edge cases (e.g., "handle 10k+ rows") but tests don't cover them

Be explicit: quote the acceptance criterion and show the code (or absence of code) that contradicts it.

### Step 5: Write Review

Write findings to a temp file:

```bash
cat > /tmp/pr<N>-review.md << 'EOF'
## Review — <PR title>

---

### 1. <Concise title>

**File:** `path/to/file.go`

```go
<relevant code snippet>
```

<explanation of the adverse finding>

**Fix:** <specific recommendation>

---

### 2. ...
EOF
```

Use `---` separators between findings for readability.

### Step 6: Post Review

```bash
cd <repo> && gh pr review <number> --comment --body-file /tmp/pr<N>-review.md
```

Verify it posted:

```bash
gh pr view <number> --json reviews
```

## Special Cases

### Migration PRs (Delete TS → Add Go)

These are the highest-risk PRs. Always:
1. Read the deleted TS file from the base branch
2. Read the new Go file from the PR branch
3. Check for **lost side effects** — any `fetch()`, `posthog.capture()`, `Sentry.*`, `revalidatePath()`, or `console.error()` calls that don't have a Go equivalent
4. Check the **frontend callers** — grep for the API path in `src/` to see what response shape they expect

### Contract Mismatch Detection

When you suspect a mismatch, grep the frontend:

```bash
cd <repo> && grep -rn "api/admin/users\|api/projects/.*/export" src/components/ src/lib/ src/app/ --include="*.ts" --include="*.tsx"
```

Then read the relevant component to see how it destructures the response.

### Multiple PRs

Review can be parallelized across PRs using subagents. Each subagent:
1. Gets one PR number
2. Runs the full review workflow above
3. Writes findings to a shared directory (e.g., `/tmp/pr-reviews/`)

The main agent then posts all reviews. Use the `pi-subagents` skill for this.

## Anti-Patterns to Avoid

- ❌ Posting "Looks good!" or positive callouts
- ❌ Reviewing only the diff without reading full files
- ❌ Catching style issues (naming, indentation) before correctness issues
- ❌ Using `--request-changes` (blocked for self-authored PRs)
- ❌ Writing the review body inline in bash (escaping hell) — always use `--body-file`
