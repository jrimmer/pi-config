---
name: supe-plan
description: Use when you have an approved design spec. Breaks work into bite-sized tasks with exact file paths, code guidance, and verification steps. Never invoked before supe-design.
---

# supe-plan

Read the approved spec and produce a detailed implementation plan.

## Prerequisites

- An approved design spec at `docs/specs/YYYY-MM-DD-<topic>-design.md`
- Read the spec fully before creating any tasks

## Workflow

Create a todo for each step and complete them in order:

1. **Read spec** — load the design doc; understand scope, decisions, constraints
2. **Map file structure** — identify every file to create or modify and its responsibility
3. **Decompose into tasks** — each task is one action a skilled engineer can complete in 2-5 minutes
4. **Write plan doc** — save to `docs/plans/YYYY-MM-DD-<feature>.md`
5. **Identify parallel groups** — which tasks are independent and can run in parallel subagents?
6. **Select mode** — ask user: "Light mode (manual gates) or dark mode (auto-flow through implement → review)?"
7. **Record mode in plan doc** — append `**Mode:** [light | dark]` to the plan header
8. **Transition**
   - If `dark`: announce "Proceeding to supe-implement" and invoke `/skill:supe-implement`
   - If `light`: stop. Tell user: "Plan complete. Review the plan, then say 'implement' to continue, or ask questions."

## Task Granularity

Each step is one action:
- "Write the failing test for X" — step
- "Run it to confirm it fails" — step
- "Implement minimal code to make test pass" — step
- "Run tests to confirm green" — step
- "Commit with descriptive message" — step

## Plan Doc Header

```markdown
# [Feature] Implementation Plan

**Goal:** [One sentence]
**Source spec:** [Link to design doc]
**Mode:** [light | dark]

## File Map

| File | Responsibility | Create / Modify |
|------|---------------|-----------------|

## Tasks

### Group A: [Independent group name]
- [ ] Task 1: [exact action]
- [ ] Task 2: [exact action]

### Group B: [Dependent on Group A]
- [ ] Task 3: [exact action]
```

## Rules

- DRY — don't repeat context the spec already covers
- YAGNI — no speculative tasks
- Every task has exact file paths
- Every task has a verification step
- Parallel groups are explicitly called out for `/subagent` with `worktree: true`
