---
name: configure-statusline
description: Install, update, or uninstall the Ghost.sec9 statusline. Drives an AskUserQuestion-based flow with three actions — install (detect any existing statusLine: auto-upgrade an older Ghost.sec9 copy in place, back up + replace a third-party one after confirmation, else write fresh), update (re-resolve the script path after `/plugin update`), uninstall (remove the `statusLine` block this skill wrote). Use when the user asks to enable, refresh, or remove the statusline.
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

Also capture the **resolved version** of the statusline being installed — parse it from the resolved script (see the helpers below). This is the version the install/upgrade logic compares against.

## Identity & version helpers

Our statusline carries two machine-readable header comments near the top of `statusline.sh`:

```
# Statusline-ID: ghost-sec9
# Statusline-Version: 0.2.0
```

These — **not** the filename — are how the skill recognises our statusline and decides whether an installed copy is older. Use these idioms:

```bash
# Extract the script path from a settings.json statusLine.command value.
# Our installs write a bare path; a third-party command may be `bash /x.sh --flag`.
# Avoids relying on word-splitting — the skill's commands may run under zsh.
sl_script_path() {  # $1 = command string
  if [[ -f "$1" ]]; then printf '%s' "$1"; return; fi
  local p; p=$(printf '%s' "$1" | grep -oE '[^[:space:]]+\.sh' | head -1)
  printf '%s' "${p:-$1}"
}

# Read our headers from a script file (empty if absent / file unreadable).
sl_id()  { grep -m1 '^# Statusline-ID:'      "$1" 2>/dev/null | sed 's/^[^:]*:[[:space:]]*//'; }
sl_ver() { grep -m1 '^# Statusline-Version:' "$1" 2>/dev/null | sed 's/^[^:]*:[[:space:]]*//'; }

# True iff version $1 is strictly older than $2 (semver via sort -V).
sl_older() {  # $1 = installed, $2 = candidate
  [[ "$1" != "$2" && "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -1)" == "$1" ]]
}
```

A file is **ours** iff `sl_id <file>` equals `ghost-sec9`. Anything else (different ID, no header, or unreadable file) is treated as **not ours**.

> **zsh caution:** these commands may run under zsh. Do **not** name a shell variable `path` — in zsh `path` is tied to `$PATH`, so `local path=…` (or a bare `path=…` in a function) blanks `$PATH` and every external command (`jq`, `grep`, `sed`) silently fails. Use `cmd`, `sp`, `iv`, `rv`, etc.

## Step 3 — dispatch

### Install

1. Ask scope via AskUserQuestion:
   - question: `"Which settings scope should the statusLine block be written to?"`
   - header: `"Scope"`
   - options:
     1. `User (Recommended)` — `~/.claude/settings.json` — applies to every project
     2. `Project` — `<cwd>/.claude/settings.json` — only this project

2. Compute the target settings path. If the parent dir is missing, `mkdir -p` it. If the file is missing, treat its existing content as `{}`.

3. **Detect the existing `.statusLine`** (`jq -r '.statusLine.command // empty'`) and branch:

   **(a) Absent** → fresh install. Go to step 4 (write).

   **(b) Present and it's OURS** — `sl_id "$(sl_script_path "$cmd")"` == `ghost-sec9`:
   - Read the installed version with `sl_ver`, and the resolved (new) version from the resolved script.
   - **Installed version == resolved version AND the installed command already equals the resolved path** → report **"already current (vX.Y.Z)"** and stop. Nothing to write.
   - **Installed older (`sl_older installed resolved`) OR the command path differs from the resolved path** (stale path from a `/plugin update`) → **auto-upgrade, no prompt**: back up the settings file, then write the resolved block (step 4). Report it as an upgrade: `vX.Y.Z → vA.B.C` (or `re-pointed to current path` when only the path moved).
   - **Installed *newer* than resolved** (you'd be downgrading — unusual) → do NOT auto-write. Show both versions and AskUserQuestion `Downgrade` / `Cancel`; only write on `Downgrade`.

   **(c) Present and it's NOT ours** — a different statusline (different ID, no header, or the script file is unreadable/missing with a non-`statusline.sh` basename):
   - STOP and AskUserQuestion:
     - question: ``"You already have a different statusline installed (`<cmd>`). Back it up and replace it with the Ghost.sec9 statusline?"``
     - header: `"Replace?"`
     - options: 1. `Back up & install (Recommended)` — copy the settings file to `.bak` (preserving their `statusLine` block) then install ours · 2. `Cancel` — leave their statusline untouched
   - On `Cancel` → stop, change nothing.
   - On `Back up & install` → proceed to step 4 (the backup in step 4 preserves their old block; tell them they can restore it from the `.bak`).

   > Edge case — the command's basename **is** `statusline.sh` but the file is missing/unreadable (e.g. an old plugin version dir was garbage-collected): treat as **ours-but-stale** (branch b, "path differs") and auto-upgrade to the resolved path rather than prompting.

4. Backup: `cp "$target" "$target.bak"` (skip silently if the file doesn't exist yet). For branch (c) this `.bak` is the user's recovery copy of their previous statusline.

5. Write the merged JSON atomically (see the jq idiom below). The block to install is:
   ```json
   {
     "type": "command",
     "command": "<resolved absolute path to statusline.sh>",
     "refreshInterval": 1
   }
   ```

6. Report: the path written to, the resolved command value, the version installed (and the upgrade delta if any), the `.bak` location when one was made, and that Claude Code must be restarted for the change to take effect.

### Update

1. Read both `~/.claude/settings.json` and `<cwd>/.claude/settings.json` (each may or may not exist).

2. For each whose `.statusLine` is **ours** (`sl_id "$(sl_script_path "$cmd")"` == `ghost-sec9`, or the script file is missing but the command basename is `statusline.sh`):
   - If the command already equals the freshly-resolved path **and** the installed version equals the resolved version → report `"already current (vX.Y.Z)"`.
   - Else → backup, then update only the `command` field (preserve `type`, `refreshInterval`, and any other keys the user added). Report the version delta when the installed version was readable.

3. Never modify a `.statusLine` that is **not** ours — report what's there and skip that file.

4. If neither file has our `statusLine`, tell the user there is nothing to update and suggest running install.

### Uninstall

1. Read both settings files.

2. For each whose `.statusLine` is **ours** (`sl_id "$(sl_script_path "$cmd")"` == `ghost-sec9`, or the script file is missing but the command basename is `statusline.sh`):
   - Backup, then `jq 'del(.statusLine)'`, atomic write.

3. If a `.statusLine` exists that is **not** ours, do NOT delete it — report what's there and skip that file.

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

- **Identity is by `# Statusline-ID: ghost-sec9`, never by filename.** Only a file carrying that ID counts as ours; the `statusline.sh` basename is a fallback signal used only when the script file can't be read.
- **Never** delete or overwrite a `.statusLine` that isn't ours without an explicit AskUserQuestion confirmation.
- **Auto-replace without a prompt is allowed only for our own, older (or stale-path) statusline** (Install branch b). A third-party statusline always requires the backup-and-replace confirmation (Install branch c).
- **Always** make a `.bak` copy before any write to a file that already exists.
- jq round-trips will re-order keys alphabetically — this is acceptable and the trade-off of using jq over a bespoke patcher. Do not attempt to preserve key order.
- Verify the resolved script path exists *before* writing it into `settings.json`. A bad path silently breaks the statusline at next session start.
