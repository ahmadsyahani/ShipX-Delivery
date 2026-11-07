# ShipX contributor instructions

## Project context

- Read `HANDOFF_CODEX_ShipX.md` and the active checkpoint documents it links before changing application behavior.
- Preserve `.env`, existing setup, and business data. Never stage secrets or generated build artifacts.

## Commit attribution

- Keep the user's configured Git author and committer identity.
- For commits containing work materially authored by Codex, append this trailer after a blank line:

  ```text
  Co-authored-by: Codex <codex@openai.com>
  ```

- Preserve existing co-author trailers, including in prepared squash commit messages.
- Do not add Codex credit to work it did not help author.
- Do not amend published commits or force-push merely to add attribution.
- Use `develop` for the current development workflow. Merge into `main` only when the user requests it and the changes are ready; adding attribution alone is not a reason to merge.
