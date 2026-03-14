# Proposals — CLAUDE.md

## What This Folder Is

`docs/proposals/` contains feature proposals and technical explorations for Odyssey. These are investigatory documents — some will become features, others will be shelved. They are NOT committed plans; they exist to capture research, weigh trade-offs, and inform decisions.

## Writing a Proposal

Each proposal should include:

1. **YAML frontmatter** with `title`, `status`, `date`, and `tags`
2. **Summary** — 2-3 sentence elevator pitch
3. **Motivation** — Why this matters for Odyssey users
4. **Technical Approach** — How it would be built, with code samples where useful
5. **Integration Points** — Where it touches the existing codebase (files, services, views)
6. **Trade-offs & Constraints** — OS version requirements, device limitations, privacy implications
7. **Open Questions** — Unresolved decisions
8. **Next Steps** — Concrete actions to move forward

## Conventions

- Number files sequentially: `001-`, `002-`, etc.
- Use status labels defined in README.md
- Keep proposals self-contained — a reader should understand the idea without external context
- Include code snippets in Swift where relevant (this is an iOS project)
- Reference existing files by path relative to repo root (e.g., `Odyssey/Views/GuidedPrompts/`)
