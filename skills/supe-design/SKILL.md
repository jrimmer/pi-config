---
name: supe-design
description: Use when creating features, building components, adding functionality, or modifying behavior. Design-first hard gate — no code until spec is explored, written, and approved.
---

# supe-design

Explore requirements and produce an approved design spec before any implementation.

## Hard Gate

Do NOT write code, scaffold files, or invoke implementation skills until the design is presented, approved, and saved to disk. This applies to every project regardless of perceived simplicity.

## Workflow

Create a todo for each step and complete them in order:

1. **Explore project context** — read files, docs, recent commits, existing patterns
2. **Assess scope** — if the request describes multiple independent subsystems, flag decomposition before asking detailed questions
3. **Ask clarifying questions** — one at a time, understand purpose, constraints, success criteria
4. **Propose 2-3 approaches** — with trade-offs and your recommendation
5. **Present design sections** — scaled to complexity; get approval after each section
6. **Write design doc** — save to `docs/specs/YYYY-MM-DD-<topic>-design.md`
7. **Spec self-review** — check for placeholders, contradictions, ambiguity, scope creep
8. **User reviews written spec** — ask user to read the file and approve or request changes
9. **Transition** — stop. Tell user: "Design complete. Review the spec, then say 'plan' to continue, or ask questions."

## Design Doc Template

```markdown
# Design: [Feature Name]

**Goal:** [One sentence]

**Background:** [Why this exists]

**Approach:** [Chosen approach + rationale]

**Rejected alternatives:** [Other approaches + why rejected]

**Scope:** [In scope / out of scope]

**Key decisions:** [Architecture, data model, API shape, UX]

**Open questions:** [Any unresolved items]
```

## Anti-Patterns

- "This is too simple to need a design" — simple projects are where assumptions cause the most waste
- Combining the design approval with the plan — they are separate phases
- Writing code during design exploration — the hard gate exists for a reason
