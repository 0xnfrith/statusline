# statusline

Themed Claude Code statusline — Section 9 / Ghost in the Shell aesthetic. Two lines, pure inline, no MCP server, no external dependencies beyond `jq` + `git` + `date`.

```
main ◆ ~/HUB/statusline ◆ opus ◆ ███▒░░░░░░ 38% ◆ EFF high
幽霊 ghost.sec9 ▸ ┄┄ 「 The net is vast and infinite. 」 ┄┄ ◆ BKK 17:05 │ EST 06:05 │ PST 03:05
```

**Line 1** is live session state — branch, cwd, model, context-window fill, and reasoning-effort level (`low`/`medium`/`high`/`xhigh`/`max`, color-coded). **Line 2** is the persistent identity frame — a 16-tick `幽霊 ghost.sec9 ▸` ↔ `公安 ｾｸｼｮﾝ9 ｺｳｱﾝ▶` glitch animation, a minute-parity rotation through 12 GITS quotes with a 6-second breath-glow, and the BKK/EST/PST world clocks.

## Install

### Via the nfrith-plugins marketplace

```
/plugin marketplace add nfrith/plugins
/plugin install statusline@nfrith-plugins
/configure-statusline
```

`/configure-statusline` is a three-option guided flow:

1. **Install** (default) — asks whether to write the `statusLine` block to user (`~/.claude/settings.json`) or project (`<cwd>/.claude/settings.json`) scope, then writes it. It's **version-aware**: if a Ghost.sec9 statusline is already installed but older (or its path went stale after a `/plugin update`), it's replaced automatically. If a *different* statusline is already there, it asks first and backs it up before replacing.
2. **Update** — re-points your `settings.json` to the current plugin version. Claude Code installs each plugin version into its own cache dir (`~/.claude/plugins/cache/nfrith-plugins/statusline/0.3.0/statusline.sh`), and your `settings.json` holds an absolute path to one of them. So after `/plugin update statusline` downloads a new version, the old path keeps working — you silently keep rendering the old statusline until you re-point. This option does the re-pointing, and now names the exact versions: e.g. **`Update 0.2.0 → 0.3.0`**.
3. **Uninstall** — removes the `statusLine` block this skill wrote.

Our statusline is recognised by a `# Statusline-ID: ghost-sec9` header in the script — **not** by filename — so the skill never clobbers a third-party `statusLine` without asking, and always drops a `.bak` next to the file before writing. Restart your Claude Code session after install or update.

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

- **Add or change quotes**: edit the `quotes=(...)` array (line ~113).
- **Swap the identity prefix**: edit `orig_render` and `glitch_render` (lines ~140-170). The two arrays must stay position-aligned and width-matched (CJK ↔ CJK, ASCII ↔ halfwidth kana).
- **Different clock zones**: edit the three `TZ=…` lines.
- **Disable the glitch animation**: replace the `for` loop that builds `$prefix` (line ~176) with `prefix="${orig_render[*]}"`.
- **Bump the version**: when you change behaviour, bump `Statusline-Version` in `statusline.sh` *and* `version` in `.claude-plugin/plugin.json` together — the configure skill compares this header to decide whether an installed copy is older.

## Requirements

- `bash` (POSIX-friendly enough; uses `[[ ]]` and arrays)
- `jq`
- `git` (optional — branch is hidden cleanly if not in a repo)
- `date` with `TZ` and `%H:%M / %S / %M` (BSD or GNU)

## License

Apache-2.0.
