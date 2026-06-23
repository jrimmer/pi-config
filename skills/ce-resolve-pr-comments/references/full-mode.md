# Full Mode

Read this reference when Mode Detection (in SKILL.md) routes to **Full Mode** — no argument given, or a PR number was provided. Full mode processes all unaddressed comments on the PR.

## 0. Always Re-Fetch First

**Never assume the PR has no new comments.** Always run `get-pr-comments` to fetch the current state, even if you were just looking at this PR. CI re-runs on every push and can post new comments between any two turns.

If the script fails, fall back to raw `fj` calls:
```bash
fj repos pulls repo-list-reviews OWNER REPO PR --json --no-input
fj repos pulls repo-get-review-comments OWNER REPO PR REVIEW_ID --json --no-input
fj repos issues get-comments OWNER REPO PR --json --no-input
```

## 1. Fetch Unaddressed Comments

If no PR number was provided, the script detects it from the current branch (matches the branch to an open PR's head ref).

Fetch all feedback using [scripts/get-pr-comments](../scripts/get-pr-comments):

```bash
python3 scripts/get-pr-comments [PR_NUMBER] [OWNER/REPO]
```

Returns a JSON object with four keys:

| Key | Contents | Has file/line? | Markable addressed? |
|-----|----------|---------------|---------------------|
| `review_comments` | Inline code review comments across ALL reviews (flat list; each carries `addressed`, `review_id`, `path`, `position`) | Yes | Yes (👍 reaction) |
| `pr_comments` | Top-level PR conversation comments (issue comments; excludes PR author + CI bots) | No | Yes (👍 reaction) |
| `review_bodies` | Review submissions with non-empty body text (excludes PR author + CI bots) | No | No (no reaction marker; reappear every run) |
| `cross_invocation` | `signal` (both addressed + unaddressed inline exist) + `addressed_comments` (last 10 addressed, for cluster analysis) | — | — |

The `addressed` flag is `true` when the comment already has a 👍 (+1) reaction from the token user — i.e. a previous run (or a human) marked it done. Treat `addressed == true` like GitHub's `isResolved == true`: skip it.

Forgejo groups conversations by `(path, line/position)` across reviews, so a comment's thread identity is `(review_id, path, position)`. Replies use the same path + position to thread into the conversation.

## 2. Triage: Separate New from Pending

Before processing, classify each piece of feedback as **new** or **already handled**.

**Addressed flag**: `review_comments` and `pr_comments` with `addressed == true` are already handled — skip them entirely. This is the primary skip signal (replaces GitHub's `isResolved`).

**Pending decisions**: For `addressed == false` comments, read the thread. If there's a substantive reply that acknowledges the concern but defers action (e.g., "need to align on this", "going to think through this"), it's a **pending decision** — don't re-process. If there's only the original reviewer comment(s) with no substantive response, it's **new**.

**PR comments and review bodies**: These have no resolve mechanism and reappear on every run. Apply two filters in order:

1. **Actionability**: Skip items with no actionable feedback or questions. Examples: review wrapper text ("🤖 AI Architecture Review — PR #31"), approvals, status badges, CI summaries with no follow-up asks. If there's nothing to fix, answer, or decide, drop it silently.
2. **Already replied**: For actionable items, check the PR conversation for an existing reply that quotes and addresses the feedback. If a reply already exists, skip. If not, it's new.

The distinction is about content, not who posted what. Bot feedback that requests a specific code change is actionable; a bot's boilerplate header wrapping those requests is not.

**⚠️ Critical: Do NOT drop findings inside AI review wrappers.**
An AI review bot's wrapper text ("🤖 AI Architecture Review — PR #31") is non-actionable boilerplate and should be silently dropped. But the **individual findings within that review** (numbered items, code change requests, questions) are actionable and MUST be processed as individual items. The wrapper is the envelope; the findings are the content. Never conflate the two.

**Silent drop.** Non-actionable items are dropped without narration. Do not announce, list, or count dropped items.

**If there are no new items across all feedback types**, re-fetch once to confirm (CI may have posted new comments between the first fetch and now). If still empty, skip steps 3-9 and go straight to step 10.

## 3. Cross-Invocation Cluster Analysis (Gated)

Before planning and dispatching fixes, check whether the same concern has appeared across multiple review rounds — evidence of a recurring pattern that warrants broader investigation.

**Gate check (two stages)**: Both must pass, or skip to step 4.

1. **Signal stage**: `cross_invocation.signal == true` — addressed inline comments exist alongside new ones. First-round reviews always fail this stage.
2. **Spatial-overlap precheck**: at least one new `review_comment` shares an exact file path or directory subtree with a comment in `cross_invocation.addressed_comments`. Compares paths only — no category inference, no LLM calls. Skip this stage if the envelope lacks file paths; then the signal stage governs alone.

Only inline `review_comments` participate in the precheck. `pr_comments` and `review_bodies` have no file paths; they are always dispatched individually regardless of clustering.

Single-round clustering (grouping new-only comments by theme + proximity within one review) is deliberately not performed: the evidence is too thin. First-round "one helper would fix all of these" opportunities are handled as individual fixes until repeated reviewer evidence promotes the pattern into cross-invocation mode.

**If both gate stages pass**, analyze feedback for thematic clusters spanning new comments and previously-addressed comments. Include addressed comments from `cross_invocation.addressed_comments` alongside new ones. Mark prior-addressed comments as `previously_addressed` so dispatch (step 5) knows not to individually re-handle them.

1. **Assign concern categories** from this fixed list: `error-handling`, `validation`, `type-safety`, `naming`, `performance`, `testing`, `security`, `documentation`, `style`, `architecture`, `other`. Each item gets exactly one category.

2. **Group by category + spatial proximity, requiring cross-round evidence**. Two items form a potential cluster when they share a concern category AND are spatially proximate (same file, or files in the same directory subtree). A cluster must contain **at least one previously-addressed comment** — a new-only group lacks cross-round evidence and is dispatched individually.

3. **Synthesize a cluster brief** for each cluster. Pass briefs to agents using a `<cluster-brief>` XML block:

   ```xml
   <cluster-brief>
     <theme>[concern category]</theme>
     <area>[common directory path]</area>
     <files>[comma-separated file paths]</files>
     <comments>[comma-separated new comment IDs]</comments>
     <hypothesis>[one sentence: what the recurring feedback across rounds suggests]</hypothesis>
     <prior-addressed>
       <comment id="1062" path="..." category="..."/>
     </prior-addressed>
   </cluster-brief>
   ```

4. **Items not in any cluster** remain individual. Previously-addressed comments that don't cluster with any new comment are dropped — they provided context but no cross-round pattern was found.

5. **If no clusters are found** after analysis, proceed with all items as individual.

## 4. Plan

Create a task list of all **new** unaddressed items grouped by type (code changes, questions, style/convention fixes, test additions). If step 3 produced clusters, include them as cluster items alongside individual items.

## 5. Implement (PARALLEL)

Process all three feedback types. Review comments are the primary type; PR comments and review bodies are secondary but should not be ignored.

### Dispatch boundary for previously-addressed comments

Previously-addressed comments (from `cross_invocation.addressed_comments`) participate in clustering and appear in cluster briefs as `<prior-addressed>` context. They are NEVER individually dispatched — they were already handled. Only new comments get individual or cluster dispatch.

### Individual dispatch (default)

**For review comments** (`review_comments`): Spawn a `ce-pr-comment-resolver` agent for each new, non-clustered comment. Each agent receives:
- The comment `id` and `review_id`
- `path`, `position`, `original_position` (any can be null/0; position can drift if the diff shifted since the review)
- The full comment `body`
- The PR number (for context)
- The feedback type (`review_comment`)

**For PR comments and review bodies** (`pr_comments`, `review_bodies`): These lack file/line context. Spawn a `ce-pr-comment-resolver` agent for each actionable non-clustered item. The agent receives the comment id, body, PR number, and feedback type (`pr_comment` or `review_body`). The agent identifies relevant files from the comment text and the PR diff. (Review bodies have no comment id — use the `review_id`.)

### Cluster dispatch

For each cluster, dispatch ONE `ce-pr-comment-resolver` agent that receives the `<cluster-brief>`, all comment details in the cluster, the PR number, and feedback types. The cluster agent reads the broader area before making targeted fixes. It returns one summary per comment, plus a `cluster_assessment`.

### Agent return format

Each agent returns a short summary:
- **verdict**: `fixed`, `fixed-differently`, `replied`, `not-addressing`, `declined`, or `needs-human`
- **feedback_id**: the comment id (or review_id for review bodies)
- **feedback_type**: `review_comment`, `pr_comment`, or `review_body`
- **reply_text**: the markdown reply to post (quoting the relevant part of the original feedback)
- **files_changed**: list of files modified (empty if replied/not-addressing)
- **reason**: brief explanation

Cluster agents additionally return **cluster_assessment**.

Verdict meanings:
- `fixed` -- code change made as requested
- `fixed-differently` -- code change made, better approach than suggested
- `replied` -- no code change; answered a question or explained a design decision
- `not-addressing` -- feedback is factually wrong about the code; skip with evidence
- `declined` -- observation may be valid, but the fix would make the code worse; reply cites the specific harm
- `needs-human` -- cannot determine the right action; needs user decision

### Batching and conflict avoidance

**Batching**: Clusters count as 1 dispatch unit. 1-4 units total → all in parallel. 5+ units → batch in groups of 4.

**Conflict avoidance**: No two dispatch units that touch the same file run in parallel. Check file overlaps across all units before dispatching; serialize overlapping units. Non-overlapping units run in parallel.

**Sequential fallback**: Platforms that don't support parallel dispatch run agents sequentially — cluster units first (higher-leverage), then individual items.

## 6. Validate Combined State

After all agents complete, aggregate `files_changed` across every summary. If empty (all verdicts are `replied`/`not-addressing`/`declined`/`needs-human`) — skip steps 6 and 7, proceed to step 8.

Run the project's full validation **once** against the combined diff (the repo's AGENTS.md/CLAUDE.md specifies the command — e.g. `mix test`, `mix credo`).

1. Run validation once, not per-agent.
2. **Green** → proceed to step 7.
3. **Red, failures touch resolver-changed files** → one inline diagnose-and-fix pass, re-run. If still red, escalate with a `needs-human` item containing the test output; do **not** commit.
4. **Red, failures touch only unchanged files** → pre-existing. Proceed to step 7, but add a commit-message footer: `Note: pre-existing failure in <test> not addressed by this PR.`

Record the validation outcome for the step 10 summary.

## 7. Commit and Push

1. Stage only files reported by sub-agents and commit referencing the PR:
```bash
git add [files from agent summaries]
git commit -m "Address PR review feedback (#PR_NUMBER)

- [list changes from agent summaries]"
```

2. Push:
```bash
git push
```

## 8. Reply and Mark Addressed

After the push succeeds, post replies and mark each handled comment addressed. The mechanism depends on the feedback type.

### Reply format

All replies quote the relevant part of the original feedback for continuity.

For fixed items:
```markdown
> [quoted relevant part of original feedback]

Addressed: [brief description of the fix]
```

For not-addressing / declined / needs-human, use the same patterns as the GitHub variant (quote + `Not addressing:` / `Declined:` / acknowledgment). For `needs-human`, post the reply but do NOT mark addressed — leave it open for human input.

### Review comments (inline)

1. **Reply** using [scripts/reply-to-pr-comment](../scripts/reply-to-pr-comment) — inline form (threads into the conversation at the same path + position):
```bash
echo "REPLY_TEXT" | bash scripts/reply-to-pr-comment OWNER REPO PR_NUMBER REVIEW_ID PATH POSITION
```

2. **Mark addressed** using [scripts/mark-comment-addressed](../scripts/mark-comment-addressed) (posts a 👍 reaction, idempotent):
```bash
bash scripts/mark-comment-addressed OWNER REPO COMMENT_ID
```

### PR comments and review bodies

PR comments: reply with a top-level PR comment, then mark addressed with a 👍:
```bash
echo "REPLY_TEXT" | bash scripts/reply-to-pr-comment OWNER REPO PR_NUMBER
bash scripts/mark-comment-addressed OWNER REPO COMMENT_ID
```

Review bodies: reply with a top-level PR comment referencing the review. Review bodies have no single comment id to react to, so they cannot be marked addressed and will reappear on re-runs — the triage step's "already replied" filter (step 2) handles them.

## 9. Verify

Re-fetch feedback to confirm comments are marked addressed:

```bash
python3 scripts/get-pr-comments PR_NUMBER
```

The set of `review_comments` and `pr_comments` with `addressed == false` should be empty (except `needs-human` items, which are intentionally left unaddressed).

**If unaddressed comments remain**, check the iteration count:

- **First or second fix-verify cycle**: Repeat from step 2 for the remaining comments. The re-fetch will pick up newly-addressed comments in `cross_invocation`, so the gate (step 3) fires naturally if patterns emerge across cycles.
- **After the second fix-verify cycle** (3rd pass would begin): Stop looping. Surface remaining issues to the user with context about the recurring pattern. Leave those comments unaddressed and present the pattern for the user to decide.

PR comments and review bodies have no addressed-marker (review bodies) or rely on the reaction (pr_comments), so verify they were replied to by checking the PR conversation for your reply.

## 10. Summary

Present a concise summary of all work done. Group by verdict, one line per item describing *what was done*.

```
Resolved N of M new items on PR #NUMBER (Forgejo):

Fixed (count): [brief description of each fix]
Fixed differently (count): [what was changed and why the approach differed]
Replied (count): [what questions were answered]
Not addressing (count): [what was skipped and why]
Declined (count): [what was declined and the harm cited]

Validation: [one line — e.g., "mix test passed (893/893)"; omit when no code changes were committed]
Marked addressed: N comments received a 👍 reaction.
```

If any clusters were investigated, append a cluster investigation section (one line per cluster: theme, area, cluster_assessment).

If any agent returned `needs-human`, append a decisions section presenting the `decision_context` (quoted feedback, investigation findings, why it needs a decision, options with tradeoffs, the agent's lean). Use the platform's blocking question tool (`ask_user` in Pi, `AskUserQuestion` in Claude Code, `request_user_input` in Codex) to ask about all pending decisions together. `needs-human` comments have an acknowledgment reply posted and remain unaddressed (no 👍).

If there are **pending decisions from a previous run**, surface them after the new work. If there are only pending decisions and no new work, the summary is just the pending items.