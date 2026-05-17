# statusline

Themed Claude Code statusline — Section 9 / Ghost in the Shell aesthetic. Two lines, pure inline, no MCP server, no external dependencies beyond `jq` + `git` + `date`.

```
幽霊 ghost.sec9 ▸ main ◆ ~/HUB/statusline ◆ opus ◆ ███▒░░░░░░ 38% ◆ BKK 17:05 │ EST 06:05 │ PST 03:05
┄┄ 「 The net is vast and infinite. 」 ┄┄
```

Includes a 16-tick `幽霊 ghost.sec9 ▸` ↔ `公安 ｾｸｼｮﾝ9 ｺｳｱﾝ▶` glitch animation and a minute-parity rotation through 12 GITS quotes with a 6-second breath-glow.

## Install

### Via the nfrith-plugins marketplace

```
/plugin marketplace add nfrith/plugins
/plugin install statusline@nfrith-plugins
/configure-statusline
```

`/configure-statusline` is a three-option guided flow:

1. **Install** (default) — asks whether to write the `statusLine` block to user (`~/.claude/settings.json`) or project (`<cwd>/.claude/settings.json`) scope, then writes it.
2. **Update** — re-resolves the script path. The cached install path looks like `~/.claude/plugins/cache/nfrith-plugins/statusline/0.1.0/statusline.sh`, so the version segment goes stale after `/plugin update statusline`. Run this to refresh it.
3. **Uninstall** — removes the `statusLine` block this skill wrote.

It refuses to clobber any existing `statusLine` it didn't put there without asking, and always drops a `.bak` next to the file before writing. Restart your Claude Code session after install or update.

If you'd rather wire it up by hand:

```json
{
  "statusLine": {
    "type": "command",
    "command": "/absolute/path/to/statusline.sh",
    "refreshInterval": 1
  }
}
```

`refreshInterval: 1` is required — the glitch animation is second-parity, so it has to re-render every second.

> **Note on `${CLAUDE_PLUGIN_ROOT}`.** Claude Code's docs explicitly support template substitution of `${CLAUDE_PLUGIN_ROOT}` in hooks, monitors, MCP servers, and LSP commands — but **not** for `statusLine.command`. The env-var form may or may not expand depending on the Claude Code version, so the skill writes an absolute resolved path; re-run the `Update` action after `/plugin update statusline` to refresh it.

### For local development

```
claude --plugin-dir ~/HUB/statusline
/configure-statusline
```

## Tweak

The script is a single bash file. Open `statusline.sh` and:

- **Add or change quotes**: edit the `quotes=(...)` array (line ~93).
- **Swap the identity prefix**: edit `orig_render` and `glitch_render` (lines ~120-150). The two arrays must stay position-aligned and width-matched (CJK ↔ CJK, ASCII ↔ halfwidth kana).
- **Different clock zones**: edit the three `TZ=…` lines.
- **Disable the glitch animation**: replace the `for` loop that builds `$prefix` (line ~155) with `prefix="${orig_render[*]}"`.

## Requirements

- `bash` (POSIX-friendly enough; uses `[[ ]]` and arrays)
- `jq`
- `git` (optional — branch is hidden cleanly if not in a repo)
- `date` with `TZ` and `%H:%M / %S / %M` (BSD or GNU)

## License

Apache-2.0.
