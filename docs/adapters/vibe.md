# vibe: Mistral Vibe

**Account boundary:** `fileOverlay`: API keys are stored in `.env` under the Vibe home directory, which can be relocated via `VIBE_HOME`.

Mistral Vibe resolves its home directory from `VIBE_HOME`. Setting this env var to the runtime root isolates credentials (`.env`) and session data per profile.

## Install

```bash
curl -LsSf https://raw.githubusercontent.com/mistralai/mistral-vibe/main/install.sh | bash
```

Binary discovery: `%USERPROFILE%\.local\bin\vibe.cmd` (Windows), `$HOME/.local/bin/vibe` (macOS/Linux), then `vibe` on PATH.

## Quickstart

```bash
multi-cli new vibe/work
multi-cli launch vibe/work
```

## Account boundary

- Mechanism: `fileOverlay`: credentials live in `.env` inside the Vibe home directory.
- Declared launch env: `VIBE_HOME={runtimeRoot}`.
- Logout scope: profile: removing `.env` from the profile root clears credentials for that profile only.

## Shared normal state

Configuration and tooling: `config.toml`, `agents/`, `prompts/`, `skills/`, `tools/`.

## Known limitations

- Project-level `.vibe/` config is not isolated by multi-cli.
- The `vibe-acp` companion binary shares the same `VIBE_HOME` and is isolated together with the main CLI.

## Support

| Windows | macOS | Linux |
|---|---|---|
| supported | supported | supported |
