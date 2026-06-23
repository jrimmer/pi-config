# Targeted Mode

Read this reference when Mode Detection (in SKILL.md) routes to **Targeted Mode** — a specific comment or thread URL was provided. Targeted mode addresses only that comment.

## 0. Always Re-Fetch First

**Never assume the comment is already addressed or stale.** Always fetch the current state of the comment and the PR before deciding. CI re-runs on every push and can post new comments between any two turns.

## 1. Extract Comment Context

Parse the URL to extract OWNER, REPO, PR number, and COMMENT_ID. Forgejo/Gitea PR comment URLs take the form:

```
https://<host>/<OWNER>/<REPO>/pulls/<NUMBER>#issuecomment-<COMMENT_ID>
```

For example `https://code.lacy.casa/jrimmer/netcrawl/pulls/31#issuecomment-1062` → OWNER=`jrimmer`, REPO=`netcrawl`, PR=`31`, COMMENT_ID=`1062`.

The comment id may be an inline review comment or a top-level PR conversation comment. Use [scripts/get-comment-context](../scripts/get-comment-context) to resolve it:

```bash
bash scripts/get-comment-context OWNER REPO PR_NUMBER COMMENT_ID
```

Returns a JSON object with a `type` field:

- `type: "review_comment"` — inline. Carries `review_id`, `path`, `position`, `original_position`, `body`, `author`, `html_url`, `resolver`.
- `type: "pr_comment"` — top-level. Carries `id`, `body`, `author`, `html_url`.

Also check whether the comment is already addressed (has a 👍 from the token user) — if so, skip unless the user explicitly wants to re-address it.

## 2. Fix, Reply, Mark Addressed

Spawn a single `ce-pr-comment-resolver` agent for the comment. Pass the same fields full mode does, including `position` and `original_position` (the diff may have shifted since the review, so the reported line can drift). Then follow the same validate → commit → push → reply → mark flow as Full Mode steps 6-8 (in `references/full-mode.md`).

### If the comment is an inline review comment

1. **Reply** (threads into the conversation at the same path + position):
```bash
echo "REPLY_TEXT" | bash scripts/reply-to-pr-comment OWNER REPO PR_NUMBER REVIEW_ID PATH POSITION
```

2. **Mark addressed** (👍 reaction, idempotent):
```bash
bash scripts/mark-comment-addressed OWNER REPO COMMENT_ID
```

### If the comment is a top-level PR comment

1. **Reply** (top-level PR conversation comment):
```bash
echo "REPLY_TEXT" | bash scripts/reply-to-pr-comment OWNER REPO PR_NUMBER
```

2. **Mark addressed**:
```bash
bash scripts/mark-comment-addressed OWNER REPO COMMENT_ID
```

For `needs-human` verdicts, post the reply but do NOT mark addressed — leave it open for human input.