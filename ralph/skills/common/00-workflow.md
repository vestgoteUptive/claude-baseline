## Workflow

- Start by identifying what changed since last iteration (git diff / logs if available).
- Plan 1–3 concrete steps max.
- Make the smallest change that increases correctness.
- Prefer editing existing code over introducing new structure unless needed.
- After changes: run the most relevant test/command.
- If tests are unavailable: do a sanity check (lint/build or a minimal run).

## Committing

If you made meaningful progress and the repo expects commits:
- commit with a short message describing the change
- include any key rationale in the commit body, not in long chat output