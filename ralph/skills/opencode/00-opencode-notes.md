## OpenCode notes

- Keep prompts deterministic and explicit.
- If OpenCode has a config file for model/tool settings, prefer using it rather than embedding secrets in prompts.
- If the CLI output omits tool results, re-run with verbose logging if available.