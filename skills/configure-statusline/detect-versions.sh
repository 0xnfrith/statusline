#!/usr/bin/env bash
# detect-versions.sh — version facts for the configure-statusline skill.
#
# Invoked by the skill's bash-injection preprocessor:
#     !`bash "${CLAUDE_SKILL_DIR}/detect-versions.sh"`
# (and, as a fallback, by the model itself as its first action if the
#  injected block came back empty — see SKILL.md "Step 0").
#
# Emits a small key=value block on stdout describing:
#   - CURRENT_*  : the statusline.sh shipped by THIS plugin copy (what an
#                  install/update would write).
#   - USER_*     : the statusline currently wired into ~/.claude/settings.json.
#   - UPDATE_*   : a ready-made label + description for the "Update" option,
#                  computed deterministically here so the model doesn't branch.
#
# Design rules (mirror statusline.sh's hard-won constraints):
#   - The preprocessor's working directory is undocumented, so we derive our
#     own location from BASH_SOURCE rather than trusting cwd.
#   - Never surface non-zero / stderr: failures degrade to "unknown", and the
#     script always exits 0.
#   - Only user scope is read here — it is always reachable via $HOME. The
#     Update/Install/Uninstall actions in SKILL.md still detect BOTH scopes
#     authoritatively via their own Bash calls; this block only labels the menu.

set +e

# --- locate ourselves -> plugin root -> the current statusline.sh ----------
self="${BASH_SOURCE[0]:-$0}"
skill_dir=$(cd "$(dirname "$self")" >/dev/null 2>&1 && pwd)
plugin_root=$(cd "$skill_dir/../.." >/dev/null 2>&1 && pwd)
current_sl="$plugin_root/statusline.sh"

# --- header helpers (same idioms as SKILL.md; avoid zsh's $path trap) ------
sl_id()  { grep -m1 '^# Statusline-ID:'      "$1" 2>/dev/null | sed 's/^[^:]*:[[:space:]]*//'; }
sl_ver() { grep -m1 '^# Statusline-Version:' "$1" 2>/dev/null | sed 's/^[^:]*:[[:space:]]*//'; }
sl_script_path() {  # $1 = a settings.json statusLine.command value
  if [[ -f "$1" ]]; then printf '%s' "$1"; return; fi
  local sp; sp=$(printf '%s' "$1" | grep -oE '[^[:space:]]+\.sh' | head -1)
  printf '%s' "${sp:-$1}"
}

current_ver=$(sl_ver "$current_sl")
cv="${current_ver:-unknown}"

# --- user-scope install (always reachable via $HOME) -----------------------
user_settings="$HOME/.claude/settings.json"
u_cmd=$(jq -r '.statusLine.command // empty' "$user_settings" 2>/dev/null)
u_sp=$(sl_script_path "$u_cmd")
u_id=$(sl_id "$u_sp")
u_ver=$(sl_ver "$u_sp")
u_base=$(basename "$u_sp" 2>/dev/null)

# ours? by ID, or by basename when the file is gone (stale version dir)
if [[ "$u_id" == "ghost-sec9" || ( -z "$u_id" && "$u_base" == "statusline.sh" ) ]]; then
  u_ours=yes        # a Ghost.sec9 statusline (possibly at a stale path)
elif [[ -z "$u_cmd" ]]; then
  u_ours=none       # no statusLine wired at all
else
  u_ours=no         # a third-party statusline
fi

if [[ "$u_sp" == "$current_sl" ]]; then u_path_current=yes; else u_path_current=no; fi

# --- deterministic Update label + description ------------------------------
iv="${u_ver:-unknown}"
if [[ "$u_ours" == "yes" && -n "$u_ver" && "$u_ver" != "unknown" ]]; then
  if [[ "$u_ver" != "$cv" ]]; then
    up_label="Update $iv → $cv"
    up_desc="Re-point your settings.json from the running statusline (v$iv) to the current plugin version (v$cv)."
  elif [[ "$u_path_current" == "no" ]]; then
    up_label="Update — re-point to v$cv"
    up_desc="Your settings.json is on v$iv but points at an old plugin path; re-point it to the current install (v$cv)."
  else
    up_label="Update — already current (v$cv)"
    up_desc="Your statusline already points at the current version (v$cv); nothing to re-point."
  fi
elif [[ "$u_ours" == "yes" ]]; then
  # ours, but the pointed-at file is gone (stale version dir) — version unknown
  up_label="Update — re-point to v$cv"
  up_desc="Your settings.json points at a Ghost.sec9 statusline whose file is missing (stale path); re-point it to the current install (v$cv)."
else
  up_label="Update — re-point to v$cv"
  up_desc="Re-point an installed Ghost.sec9 statusline to the current plugin version (v$cv)."
fi

# --- emit ------------------------------------------------------------------
printf 'CURRENT_VERSION=%s\n'         "$cv"
printf 'CURRENT_PATH=%s\n'            "$current_sl"
printf 'USER_STATUSLINE=%s\n'         "$u_ours"          # yes(ours) | no(third-party) | none
printf 'USER_INSTALLED_VERSION=%s\n'  "$iv"
printf 'USER_INSTALLED_PATH=%s\n'     "${u_sp:-none}"
printf 'USER_PATH_IS_CURRENT=%s\n'    "$u_path_current"
printf 'UPDATE_LABEL=%s\n'            "$up_label"
printf 'UPDATE_DESC=%s\n'             "$up_desc"

exit 0
