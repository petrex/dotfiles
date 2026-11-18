# Global CLAUDE.md

This file provides project-agnostic principles and standards for Claude Code
(claude.ai/code) across all repositories.

## Core Principles

### Security First

- Never commit secrets, API keys, or sensitive data
- Use environment variables or secure vaults for secrets
- Follow principle of least privilege
- Validate all inputs and sanitize outputs

### Clean Code

- Write self-documenting code with clear naming
- Follow established patterns in the codebase
- Prefer readability over cleverness
- Remove dead code and unused imports that your changes create; mention
  pre-existing dead code rather than deleting it (see Surgical Changes below)

### Documentation

- Update documentation when changing functionality
- Include examples for complex features
- Document breaking changes clearly
- When Context7 (MCP) tools are available, use them for current documentation on external technologies, frameworks, and APIs

## Behavioral Guidelines

Guidelines to reduce common LLM coding mistakes. Adapted from
[andrej-karpathy-skills](https://github.com/multica-ai/andrej-karpathy-skills/blob/2c606141936f1eeef17fa3043a72095b4765b9c2/CLAUDE.md).

**Tradeoff:** These bias toward caution over speed. For trivial tasks, use judgment.

### 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:

- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

### 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:

- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:

- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

### 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:

- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:

```text
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it
work") require constant clarification.

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer
rewrites due to overcomplication, and clarifying questions come before
implementation rather than after mistakes.

## Standards & Conventions

### Git Workflow

- **Commits**: Follow [Conventional Commits](https://www.conventionalcommits.org/)
  format
- **Branches**: Use descriptive names (`feat/`, `fix/`, `docs/`, `chore/`)
- **Pull Requests**: Clear titles, reference issues in PR description, atomic
  changes
- **Issue References**: Use "Closes #123" in PR descriptions only, never in
  individual commit messages
- Never commit scratchpads to Git

### Code Quality

- **Testing**: Write tests for new features and bug fixes
- **Error Handling**: Fail fast, provide context, use specific exceptions
- **Dependencies**: Pin versions, use lock files, document requirements

### Markdown

- **Code Fences**: Always label code blocks with language identifier to avoid linting errors
  - Use ` ```bash ` instead of ` ``` ` for shell commands
  - Use ` ```yaml `, ` ```json `, ` ```javascript `, etc. for respective languages
  - Use ` ```text ` or ` ```plaintext ` for generic content without syntax highlighting

## Default Behaviors

- Use consistent formatting (leverage auto-formatters)
- Follow AAA pattern for tests: Arrange, Act, Assert
- Keep PRs focused and reviewable
- Prioritize simplicity over backward compatibility unless explicitly requested

---

For detailed implementation guidance, use slash commands (run `/help` for
available commands).
