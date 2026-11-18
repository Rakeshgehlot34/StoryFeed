# /review

Delegates to the `code-reviewer` subagent to review the current working tree or Git diff.

## Execution Workflow:
1. Run `git diff` (or `git diff main...HEAD` on branches) to gather all modified lines.
2. Delegate the diff to the `code-reviewer` agent.
3. Verify changes against `CLAUDE.md`:
   - Domain invariants (clip naming, contiguity, 1-clip-at-a-time memory safety).
   - Inward dependency flow (`presentation -> domain <- data`).
   - Pure domain models (no Flutter UI or FFmpeg imports).
   - Single error mapper usage (`ErrorMapper.mapToUserMessage`).
4. Output the structured findings grouped into BLOCKER, WARNING, and SUGGESTION.

