#!/bin/bash
# statusline.sh — Themed Claude Code statusline (pure inline, no external data)
#
# Statusline-ID: ghost-sec9
# Statusline-Version: 0.2.0
#   ^ Machine-readable identity + upgrade key, parsed by the
#     configure-statusline skill to tell our statusline apart from a
#     third-party one and to decide whether an installed copy is older.
#     Keep Statusline-Version in lockstep with .claude-plugin/plugin.json.
#
# Rows:
#   1. BRANCH · CWD · model · ctx bar+% · effort  — live session state
#   2. 幽霊 ghost.sec9 identity glitch · 「 rotating GITS quote 」 · BKK/EST/PST
#
# Data sources:
#   - stdin JSON (Claude Code session info: cwd, model, context_window)
#   - `git branch --show-current` in $cwd (cheap, ~5ms)
#   - `date` for clocks and blink phases (free)
#
# This is the decoupled standalone face. No MCP server, no cache directory,
# no external producers. Delamain badges, OBS LIVE indicator, and the
# producer/cache protocol that drives them are deliberately out of scope —
# they belonged to an ALS-coupled system; this plugin owns nothing outside
# its own render path.
#
# CRITICAL (inherited from GHOST-163 in the ancestor implementation):
# stderr output or non-zero exit permanently disables the statusline for the
# session. Every command that can fail is either guarded or has its stderr
# suppressed. `set -e` is NOT used.

set +e

# ---------------------------------------------------------------------------
# Parse Claude Code's JSON input (single jq call)
# ---------------------------------------------------------------------------
input=$(cat)
IFS=$'\t' read -r cwd model used_pct effort <<< "$(
  echo "$input" | jq -r '[
    .workspace.current_dir // "",
    .model.display_name // "",
    (.context_window.used_percentage // "" | tostring),
    .effort.level // ""
  ] | @tsv' 2>/dev/null
)"

# CWD: replace $HOME with ~ for compactness
cwd_short="${cwd/#$HOME/~}"

# Model: first word only, lowercased — handles any model string gracefully
model_short="${model%% *}"
model_lc=$(printf '%s' "$model_short" | tr '[:upper:]' '[:lower:]')

# Branch (git is cheap, inline is fine)
branch=$(cd "$cwd" 2>/dev/null && git branch --show-current 2>/dev/null)

# ---------------------------------------------------------------------------
# Blink phases — derived from seconds. Only breath-glow is needed for the
# quote line; the glitch animation uses cur_sec directly.
# ---------------------------------------------------------------------------
cur_sec=$(( 10#$(date +%S) ))
phase_breath=$(( (cur_sec / 3) % 2 ))   # period-6s (quote breath-glow)

# ---------------------------------------------------------------------------
# Context bar — gradient fill (uses pre-calculated used_percentage)
# ---------------------------------------------------------------------------
context_info=""
if [[ -n "$used_pct" && "$used_pct" != "null" && "$used_pct" != "" ]]; then
    pct=${used_pct%.*}
    filled=$((pct * 10 / 100))
    remainder=$((pct - filled * 10))
    edge=""
    if (( remainder >= 7 )); then edge="▓"
    elif (( remainder >= 4 )); then edge="▒"
    elif (( remainder >= 1 )); then edge="░"
    fi
    bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    [[ -n "$edge" ]] && bar+="$edge"
    cur_len=${#bar}
    for ((i=cur_len; i<10; i++)); do bar+="░"; done
    context_info=$(printf ' \033[2;35m◆\033[0m \033[1;35m%s\033[0m \033[2;35m%d%%\033[0m' "$bar" "$pct")
fi

# ---------------------------------------------------------------------------
# Effort level — session reasoning effort, color-coded by intensity.
# `.effort.level` is absent when the model doesn't support the param, so the
# token simply disappears in that case.
# ---------------------------------------------------------------------------
effort_info=""
if [[ -n "$effort" && "$effort" != "null" ]]; then
    case "$effort" in
        low)    eff_color="\033[2;37m" ;;   # dim white — minimal
        medium) eff_color="\033[1;36m" ;;   # cyan
        high)   eff_color="\033[1;33m" ;;   # yellow
        xhigh)  eff_color="\033[1;35m" ;;   # magenta
        max)    eff_color="\033[1;31m" ;;   # red — full burn
        *)      eff_color="\033[1;37m" ;;   # unknown — bright white
    esac
    effort_info=$(printf ' \033[2;35m◆\033[0m \033[2;37mEFF\033[0m '"$eff_color"'%s\033[0m' "$effort")
fi

# ---------------------------------------------------------------------------
# Clocks: BKK │ EST │ PST (24h). IANA zones handle DST automatically.
# ---------------------------------------------------------------------------
bkk=$(TZ="Asia/Bangkok" date +%H:%M)
est=$(TZ="America/New_York" date +%H:%M)
pst=$(TZ="America/Los_Angeles" date +%H:%M)
clocks=$(printf ' \033[2;35m◆\033[0m \033[2;37mBKK\033[0m \033[1;97m%s\033[0m \033[2;35m│\033[0m \033[2;37mEST\033[0m \033[1;97m%s\033[0m \033[2;35m│\033[0m \033[2;37mPST\033[0m \033[1;97m%s\033[0m' "$bkk" "$est" "$pst")

# ---------------------------------------------------------------------------
# GITS quote rotation (minute-parity) — kept short to fit in frame header
# ---------------------------------------------------------------------------
quotes=(
  "The net is vast and infinite."
  "And where does the newborn go from here?"
  "Project 2501."
  "I am a living, thinking entity."
  "We are memories made flesh."
  "Your effort to remain is what limits you."
  "A copy is just an identical image."
  "Believe in yourself. Choose what to leave."
  "Section 9 is listening."
  "The newborn traverses the net."
  "Ghost line stable."
  "If a feat is possible, man will do it."
)
q_idx=$(( 10#$(date +%M) % ${#quotes[@]} ))
quote_text="${quotes[$q_idx]}"

RESET="\033[0m"

# ---------------------------------------------------------------------------
# Glitch animation prefix — leads line 2.
# ---------------------------------------------------------------------------
# Prefix glitch animation — 16-tick cycle.
#   Frame 0: original `幽霊 ghost.sec9 ▸`
#   Frame i (1-15): first i positions replaced with glitch phrase
#   Glitch phrase reads: 公安 ｾｸｼｮﾝ9 ｺｳｱﾝ▶ (kōan, section 9, kōan ▶)
#   Widths match position-for-position (CJK↔CJK, ASCII↔half-width-kana).
orig_render=(
  "\033[1;35m幽\033[0m"
  "\033[1;35m霊\033[0m"
  " "
  "\033[1;36mg\033[0m"
  "\033[1;36mh\033[0m"
  "\033[1;36mo\033[0m"
  "\033[1;36ms\033[0m"
  "\033[1;36mt\033[0m"
  "\033[1;36m.\033[0m"
  "\033[1;36ms\033[0m"
  "\033[1;36me\033[0m"
  "\033[1;36mc\033[0m"
  "\033[1;36m9\033[0m"
  " "
  "\033[2;35m▸\033[0m"
)
glitch_render=(
  "\033[1;32m公\033[0m"
  "\033[1;32m安\033[0m"
  " "
  "\033[1;32mｾ\033[0m"
  "\033[1;32mｸ\033[0m"
  "\033[1;32mｼ\033[0m"
  "\033[1;32mｮ\033[0m"
  "\033[1;32mﾝ\033[0m"
  "\033[1;32m9\033[0m"
  " "
  "\033[1;32mｺ\033[0m"
  "\033[1;32mｳ\033[0m"
  "\033[1;32mｱ\033[0m"
  "\033[1;32mﾝ\033[0m"
  "\033[1;32m▶\033[0m"
)
anim_frame=$(( cur_sec % 16 ))
prefix=""
for ((i=0; i<15; i++)); do
  if (( i < anim_frame )); then
    prefix+="${glitch_render[$i]}"
  else
    prefix+="${orig_render[$i]}"
  fi
done

# ---------------------------------------------------------------------------
# Line 1 assembly — live session state (branch · cwd · model · ctx bar)
# ---------------------------------------------------------------------------
line1=""
[[ -n "$branch" ]] && line1+=$(printf '\033[1;33m%s\033[0m \033[2;35m◆\033[0m ' "$branch")
[[ -n "$cwd_short" ]] && line1+=$(printf '\033[1;36m%s\033[0m' "$cwd_short")
[[ -n "$model_lc" ]] && line1+=$(printf ' \033[2;35m◆\033[0m \033[2;36m%s\033[0m' "$model_lc")
line1+="$context_info"
line1+="$effort_info"

# ---------------------------------------------------------------------------
# Line 2 assembly — identity glitch · rotating quote (breath-glow) · clocks
# ---------------------------------------------------------------------------
if (( phase_breath == 0 )); then quote_color="\033[0;35m"; else quote_color="\033[2;35m"; fi
line2="$(printf '%b' "$prefix")"
line2+=$(printf ' \033[2;35m┄┄\033[0m')
line2+=$(printf " ${quote_color}「 %s 」${RESET}" "$quote_text")
line2+=$(printf ' \033[2;35m┄┄\033[0m')
line2+="$clocks"

# ---------------------------------------------------------------------------
# Emit
# ---------------------------------------------------------------------------
echo "$line1"
echo "$line2"
