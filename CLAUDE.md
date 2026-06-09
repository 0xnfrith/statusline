# statusline

Themed Claude Code statusline. Pure inline. No MCP server, no cache, no external producers.

## What this is

A single bash script (`statusline.sh`) that Claude Code invokes after each assistant message. It reads the session JSON from stdin and emits two lines:

```
幽霊 ghost.sec9 ▸ <branch> ◆ <cwd> ◆ <model> ◆ <ctx-bar> ◆ BKK <hh:mm> │ EST <hh:mm> │ PST <hh:mm>
┄┄ 「 <rotating GITS quote> 」 ┄┄
```

The aesthetic is Section 9 / Ghost in the Shell — the 16-frame `幽霊 ghost.sec9 ▸` ↔ `公安 ｾｸｼｮﾝ9 ｺｳｱﾝ▶` glitch animation runs on second-parity; the quote rotates on minute-parity through 12 GITS lines with a 6-second breath-glow.

## Design contract

### What's in

- **Stdin parse** — single `jq` call extracts cwd, model display name, context-window used percentage.
- **Branch** — `git branch --show-current` in `$cwd`. Cheap (~5ms). Suppressed cleanly if cwd is not a git repo.
- **CWD** — `$HOME` is replaced with `~` for compactness.
- **Model** — first word of the display name, lowercased.
- **Context bar** — 10-cell gradient (`█▓▒░`) showing used-percentage.
- **World clocks** — BKK / EST / PST via IANA zones (DST-correct).
- **Glitch animation** — 16-tick second-parity prefix swap, position-aligned CJK ↔ halfwidth kana.
- **Quote rotation** — minute-parity index into a 12-entry GITS list, with breath-glow on a 6-second period.

### What's deliberately out

The ancestor implementation (`nfrith-repos/als/statusline/`) was an ALS-coupled system with three additional capabilities. They were removed here, not because they're bad ideas, but because they require external data and the plugin must own zero knowledge of what's producing it:

| Removed | Why |
|---|---|
| Line 2 delamain badges | Requires scanning `.claude/delamains/*/status.json` — ALS-specific schema. |
| LIVE/OFFLINE OBS indicator on line 1 | Requires a WebSocket probe to OBS — external producer. |
| PULSE MCP server | Existed only to coordinate the delamain + OBS probes on a tick and write to an atomic file cache. With those gone, there's nothing expensive enough on the render path to justify a producer/cache architecture. |
| Construct upgrade engine, migrations, `construct.json`, `VERSION` | ALS plugin framework — not portable. |
| `delamain-stop.sh` SessionEnd hook, `/configure-statusline`, `/upgrade-statusline` skills | ALS-coupled wiring. |

This plugin renders what stdin and the local clock tell it. Anything beyond that — delamain state, stream status, anything any other producer might emit — is a separate concern, addressed by some future extension model that doesn't exist yet and isn't designed here.

### Inherited constraints (GHOST-163)

The ancestor's hard-won lessons still govern the bits that remain:

1. **stderr kills rendering.** Any stderr output to the statusline causes Claude Code to render blank. All fallible commands have stderr suppressed (`2>/dev/null`) or are guarded.
2. **Non-zero exit disables the statusline for the session.** `set +e` is enforced (NOT `set -e`). Once disabled, it never comes back without restarting Claude Code.
3. **300ms debounce.** New invocations cancel in-flight ones. The current set of operations runs well under 50ms in practice — one `jq`, one `git`, three `date` calls — so cancellation isn't a concern at this scope.
4. **Multi-line + ANSI is at the edge of what Claude Code handles.** Two lines with heavy ANSI is the budget. Three lines (the ancestor's badge row) hit cancellation issues that drove the PULSE architecture. Stay at two.

### Possible future extensions (not designed, just noted)

If/when there's a real second consumer of statusline-shaped data:

- A **topic/cache protocol** could be specified: external producers atomically write JSON topic files to a known cache dir (e.g. `.claude/statusline/cache/`); the face reads any topic it understands. The plugin would ship only built-in producers (OBS, maybe), and external systems (including ALS) hook in by writing to the cache.
- A **theme abstraction** could lift the `幽霊 ghost.sec9` brand strings, color choices, and quote list into a config file.

Neither is on the critical path. They get designed when a concrete use case forces them.

The install/configure skill that was previously listed here has shipped — see `skills/configure-statusline/`.

## Files

| File | Purpose |
|---|---|
| `statusline.sh` | The face. Invoked by Claude Code, reads stdin, writes two lines to stdout. |
| `.claude-plugin/plugin.json` | Plugin manifest. |
| `skills/configure-statusline/SKILL.md` | Install/audit/update/uninstall skill. Plugin-shipped `settings.json` cannot set `statusLine` (only `agent` / `subagentStatusLine` are allowed), so this skill is the wiring step. Marked `disable-model-invocation: true` — user-invocable only (`/configure-statusline`); the model never auto-loads it, since wiring settings.json is a deliberate, side-effecting opt-in the user should trigger. |
| `README.md` | Install + tweak instructions. |
| `CLAUDE.md` | This file — design contract. |

## References

- Official Claude Code statusline docs: <https://docs.anthropic.com/en/docs/claude-code/configuration#status-line>
- Ancestor implementation: `nfrith-repos/als/statusline/` (ALS-coupled; this plugin is the decoupled descendant)
