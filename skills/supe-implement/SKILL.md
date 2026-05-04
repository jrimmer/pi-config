---
name: supe-implement
description: Use when you have an approved plan. Orchestrates parallel subagent workers with embedded TDD discipline, runs tests, dispatches dual-model code review, and presents merge/PR/keep/fix options. The terminal skill of the supe pipeline.
---

# supe-implement

Orchestrate the full build: workers → tests → dual-model review → decision.

## Prerequisites

- An approved plan at `docs/plans/YYYY-MM-DD-<feature>.md`
- The source spec at `docs/specs/YYYY-MM-DD-<topic>-design.md`

## Workflow

Create a todo for each phase and complete them in order:

### Phase 1: Read Plan & Detect Mode

Read both the plan and the spec. Extract the `Mode` field from the plan header. If missing, default to `light` and confirm with user.

### Phase 2: Dispatch Workers

Group tasks by parallel independence. For each group:

1. Create a temporary instruction file per group summarizing:
   - The group's tasks (exact file paths, expected behavior)
   - TDD discipline (see below)
   - The spec's key decisions relevant to this group
2. Dispatch a parallel `subagent` call with:
   - `agent: "worker"`
   - `worktree: true`
   - `task: <group instruction file path>`
   - `output: <group result file>`

Wait for all workers to complete. Read their outputs.

### Phase 3: Run Tests

Run the project's full test suite. If any test fails:
- Light mode: report failures, ask user whether to fix or abort
- Dark mode: auto-dispatch a fix worker for the failing tests, then re-run suite

### Phase 4: Light Mode Gate (if applicable)

If mode is `light`: ask user "Tests green. Run multi-model review now?" Wait for confirmation.

### Phase 5: Dual-Model Code Review

Dispatch **two parallel reviewer subagents** with the same comprehensive prompt. Both models review everything independently.

**Reviewer A:** `model: "ollama-cloud/kimi-k2.6"`  
**Reviewer B:** `model: "zai/glm-5.1"`

Both get this exact prompt:

```
You are reviewing an implementation against its design spec and plan.

Read the spec at <spec path> and the plan at <plan path>.
Read every file changed by the implementation.

Review against ALL of the following categories. Report adverse findings only.
Do not post praise, checkmarks, or LGTM comments.

A. Correctness
- Error return values silently discarded
- Nil pointer risks
- Race conditions or goroutine leaks
- SQL injection vectors
- Transaction rollback not deferred or ignored
- Unhandled promise rejections / async errors

B. Behavioral Regression & Contract Mismatch
- Lost side effects (analytics, cache invalidation, background jobs, logging)
- Response shape changes breaking consumers
- Status code changes
- Error handling softened
- Missing validation previously present

C. Security
- Auth/ownership checks missing or bypassed
- Input validation weakened
- Secrets logged or returned in responses
- CORS/cache headers changed inappropriately

D. Performance
- N+1 queries introduced
- Full-table scans or missing indexes
- Client-side aggregation replacing DB aggregation
- Unbounded result sets (no LIMIT)
- HTTP clients without timeouts

E. Architecture / Maintainability
- Duplicate logic with existing code
- Magic strings that should be constants
- Type safety regressions
- Test coverage gaps for new code paths
- Files that violate single-responsibility

F. Spec Conformance
- Scope creep: code beyond what the spec asked for
- Missing acceptance criteria from the spec
- Wrong solution approach vs. spec's chosen approach
- Contradictions with linked tickets or dependencies

Write your findings to <assigned output path>.
Format each finding as:

### <Concise title>
**File:** `path/to/file.ext`
```
<relevant code snippet>
```
<explanation of adverse finding>
**Fix:** <specific recommendation>
```

Stop after 1–5 high-quality adverse findings. Do not generate low-value noise.
```

Wait for both reviewers to complete. Read both outputs.

### Phase 6: Present Consolidated Findings

Deduplicate by file/issue. Present both reviewers' findings together:
- If both caught the same issue: note the consensus
- If only one caught an issue: present it (different model architectures surfaced different blind spots)
- If no findings: note "No adverse findings from either reviewer"

### Phase 7: Decision Options

Present these options and wait for user choice:

1. **/pr** — Create a pull request with the current branch
2. **/merge** — Fast-forward merge to main
3. **/fix** — Address flagged issues first (returns to Phase 2 for specific files)
4. **/keep** — Leave branch as-is, user handles merge later
5. **/discard** — Abandon the worktree/branch

For `/pr` or `/merge`: run `git diff --check`, ensure tests pass one final time, then execute.

## Embedded TDD Discipline (per worker)

Every implementer subagent must follow this:

```
## TDD Rules

1. Write the failing test FIRST. Watch it fail.
2. Write the MINIMAL code to make it pass.
3. Run tests. If green, refactor. If not, fix.
4. Delete any code you wrote before its test.

RED → GREEN → REFACTOR. No exceptions.
```

## Light vs Dark Behavior Summary

| Phase | Dark Mode | Light Mode |
|-------|-----------|------------|
| Workers | Auto-dispatch all groups | Auto-dispatch all groups |
| Tests | Auto-run; auto-fix if failing | Auto-run; pause on failure |
| Review | Auto-dispatch after tests | Ask user first |
| Decision | Auto-present options | Auto-present options |

The only difference is the review gate in light mode.
