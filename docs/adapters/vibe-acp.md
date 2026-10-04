# vibe-acp: Vibe ACP

**Account boundary:** `fileOverlay`: API keys are stored in `.env` under the Vibe home directory, which can be relocated via `VIBE_HOME`.

**Protocol:** `acp` — the launcher spawns `vibe-acp --acp` as a background server, waits for the ACP handshake, then spawns the `vibe` client connected to it.

## Install

```bash
curl -LsSf https://raw.githubusercontent.com/mistralai/mistral-vibe/main/install.sh | bash
```

Binary discovery: `vibe-acp` on PATH.

## Quickstart

```bash
multi-cli new vibe-acp/work
multi-cli launch vibe-acp/work
```

## Protocol

- Type: `acp`
- Transport: `stdio`
- Server command: `vibe-acp --acp`
- Handshake: `initialize` (10s timeout)
- Client command: `vibe`
- Client env: `ACP_SERVER_PID={serverPid}`

## Account boundary

- Mechanism: `fileOverlay`: credentials live in `.env` inside the Vibe home directory.
- Declared launch env: `VIBE_HOME={runtimeRoot}`.
- Logout scope: profile: removing `.env` from the profile root clears credentials for that profile only.

## Shared normal state

Configuration and tooling: `config.toml`, `agents/`, `prompts/`, `skills/`, `tools/`.

## Support

| Windows | macOS | Linux |
|---|---|---|
| supported | supported | supported |
