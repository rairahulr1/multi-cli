# mimocode: MiMo Code

**Account boundary:** `fileOverlay`: credentials are stored in `auth.json` under the MiMo Code data directory, which can be relocated via `MIMOCODE_HOME`.

MiMo Code resolves its data directory from `MIMOCODE_HOME` (XDG-compatible). Setting this env var to the runtime root isolates credentials (`auth.json`) and session data per profile.

## Install

```bash
npm i -g @mimo-ai/cli
```

Binary discovery: `%APPDATA%\npm\mimo.cmd` (Windows), `/usr/local/bin/mimo` (macOS), `$HOME/.npm-global/bin/mimo` (Linux), then `mimo` on PATH.

## Quickstart

```bash
multi-cli new mimocode/work
multi-cli launch mimocode/work
```

## Account boundary

- Mechanism: `fileOverlay`: credentials live in `auth.json` inside the MiMo Code data directory.
- Declared launch env: `MIMOCODE_HOME={runtimeRoot}`.
- Logout scope: profile: `mimo auth logout` clears credentials for the active profile only.

## Shared normal state

Configuration and tooling: `config.toml`, `mcp-auth.json`, `skills/`, `agents/`, `prompts/`, `mcp/`.

## Known limitations

- Config files at `~/.config/mimocode/` are shared across profiles (only the data directory is isolated).
- Project-level `.mimocode/` config is not isolated by multi-cli.

## Support

| Windows | macOS | Linux |
|---|---|---|
| supported | supported | supported |
