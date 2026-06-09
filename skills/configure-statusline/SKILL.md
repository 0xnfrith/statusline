---
name: configure-statusline
description: Install, update, or uninstall the Ghost.sec9 statusline. Drives an AskUserQuestion-based flow with three actions — install (write `statusLine` to settings.json), update (re-resolve the script path after `/plugin update`), uninstall (remove the `statusLine` block this skill wrote). Use when the user asks to enable, refresh, or remove the statusline.
disable-model-invocation: true
---

# /configure-statusline

Wires the plugin's `statusline.sh` into a Claude Code `settings.json`. Plugin-shipped `settings.json` cannot set `statusLine` (only `agent` / `subagentStatusLine` are permitted there), so the user has to opt in via their own settings file — this skill is that opt-in step.

## Step 1 — pick the action

**Immediately** call AskUserQuestion. Do not preamble.

- question: `"Configure the Ghost.sec9 statusline. What would you like to do?"`
- header: `"Statusline"`
- options (in this order):
  1. `Install (Recommended)` — write the `statusLine` block to a `settings.json`
  2. `Update` — re-resolve the script path after `/plugin update statusline`
  3. `Uninstall` — remove the `statusLine` block this skill previously wrote

## Step 2 — resolve the script path

The script lives at `<plugin_root>/statusline.sh`. To find `<plugin_root>`:

1. If `$CLAUDE_PLUGIN_ROOT` is set in the environment, use it.
2. Otherwise, derive from this SKILL.md's path: `<plugin_root>` is the directory containing `.claude-plugin/plugin.json`, two levels above `skills/configure-statusline/SKILL.md`.
3. Verify `<plugin_root>/statusline.sh` exists and is executable. If not, abort with a clear error message naming the path that was checked.

Always use the **absolute, resolved** path in `settings.json`. Do NOT write `${CLAUDE_PLUGIN_ROOT}` literally — Claude Code's docs do not guarantee env-var expansion for `statusLine.command`.

## Step 3 — dispatch

### Install

1. Ask scope via AskUserQuestion:
   - question: `"Which settings scope should the statusLine block be written to?"`
   - header: `"Scope"`
   - options:
     1. `User (Recommended)` — `~/.claude/settings.json` — applies to every project
     2. `Project` — `<cwd>/.claude/settings.json` — only this project

2. Compute the target settings path. If the parent dir is missing, `mkdir -p` it. If the file is missing, treat its existing content as `{}`.

3. Inspect the existing `.statusLine` with `jq`:
   - **Absent** → proceed to write.
   - **Present, and `.statusLine.command` basename is `statusline.sh`** → treat as a re-install; proceed (idempotent).
   - **Present, with a different command** → STOP. Show the existing block to the user and call AskUserQuestion: `Overwrite` / `Cancel`. Only proceed on `Overwrite`.

4. Backup: `cp "$target" "$target.bak"` (skip silently if the file doesn't exist yet).

5. Write the merged JSON atomically (see the jq idiom below). The block to install is:
   ```json
   {
     "type": "command",
     "command": "<resolved absolute path to statusline.sh>",
     "refreshInterval": 1
   }
   ```

6. Report: the path written to, the resolved command value, and that Claude Code must be restarted for the change to take effect.

### Update

1. Read both `~/.claude/settings.json` and `<cwd>/.claude/settings.json` (each may or may not exist).

2. For each that has a `.statusLine.command` whose basename is `statusline.sh`:
   - If the command already equals the freshly-resolved path → report "already current".
   - Else → backup, then update only the `command` field (preserve `type`, `refreshInterval`, and any other keys the user added).

3. If neither file has a managed `statusLine`, tell the user there is nothing to update and suggest running install.

### Uninstall

1. Read both settings files.

2. For each that has a `.statusLine.command` whose basename is `statusline.sh`:
   - Backup, then `jq 'del(.statusLine)'`, atomic write.

3. If a `.statusLine` exists with a different command, do NOT delete it — report what's there and skip that file.

4. Report which scopes were cleared and remind the user to restart Claude Code.

## jq atomic-write idiom

```bash
target="$1"; expr="$2"
tmp="${target}.tmp"
if [[ -f "$target" ]]; then
  jq "$expr" "$target" > "$tmp" && mv "$tmp" "$target"
else
  mkdir -p "$(dirname "$target")"
  echo '{}' | jq "$expr" > "$tmp" && mv "$tmp" "$target"
fi
```

For the install write, `$expr` is:
```
.statusLine = {type:"command", command:$cmd, refreshInterval:1}
```
passed with `--arg cmd "<resolved path>"`.

For the update write, `$expr` is:
```
.statusLine.command = $cmd
```

For the uninstall write, `$expr` is `del(.statusLine)`.

## Safety rules

- **Never** delete a `.statusLine` whose `command` basename isn't `statusline.sh`.
- **Always** make a `.bak` copy before any write to a file that already exists.
- **Always** AskUserQuestion before overwriting a third-party `statusLine`.
- jq round-trips will re-order keys alphabetically — this is acceptable and the trade-off of using jq over a bespoke patcher. Do not attempt to preserve key order.
- Verify the resolved script path exists *before* writing it into `settings.json`. A bad path silently breaks the statusline at next session start.
