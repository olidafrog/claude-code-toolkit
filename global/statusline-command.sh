#!/bin/sh
# Claude Code statusLine script
# Rainbow-colored sections with emojis, Unicode progress bar, git branch

input=$(cat)

# --- Parse all values ---
dir=$(echo "$input" | jq -r '.workspace.current_dir')
model=$(echo "$input" | jq -r '.model.display_name' | sed 's/ context//')
git_branch=$(cd "$dir" 2>/dev/null && git -c core.useBuiltinFSMonitor=false rev-parse --abbrev-ref HEAD 2>/dev/null)
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
total_in=$(echo "$input" | jq -r '.context_window.total_input_tokens // empty')
total_out=$(echo "$input" | jq -r '.context_window.total_output_tokens // empty')
effort=$(echo "$input" | jq -r '.effort.level // empty')
session_used=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
week_used=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')

# --- Thinking effort level (absent when model doesn't support it) ---
effort_disp=""
case "$effort" in
  low)    effort_disp="Low" ;;
  medium) effort_disp="Medium" ;;
  high)   effort_disp="High" ;;
  xhigh)  effort_disp="XHigh" ;;
  max)    effort_disp="Max" ;;
esac

# --- Rainbow colors (ROYGBIV) ---
RED='\033[91m'
ORANGE='\033[38;5;208m'
YELLOW='\033[93m'
GREEN='\033[92m'
BLUE='\033[94m'
INDIGO='\033[38;5;99m'
VIOLET='\033[95m'
CYAN='\033[96m'
PINK='\033[38;5;218m'
RESET='\033[0m'
DIM='\033[2m'

# --- 1. Directory (Red) ---
printf "${RED}\xE2\x8C\x82 %s${RESET}" "$(basename "$dir")"

# --- 2. Git branch (Blue) ---
if [ -n "$git_branch" ]; then
  printf " ${DIM}|${RESET} ${BLUE}\xE2\x8E\x87 %s${RESET}" "$git_branch"
fi

# --- 3. Model (yellow) + thinking effort (grey, no icon/hyphen) ---
printf " ${DIM}|${RESET} ${YELLOW}%s${RESET}" "$model"
[ -n "$effort_disp" ] && printf " ${DIM}%s${RESET}" "$effort_disp"

# --- 4. Context: ✻ marker + progress bar, both in the usage colour ---
if [ -n "$used" ]; then
  used_int=$(printf '%.0f' "$used")
  bar_width=15
  filled=$(( used_int * bar_width / 100 ))
  [ "$filled" -gt "$bar_width" ] && filled=$bar_width
  empty=$(( bar_width - filled ))

  # Bar color based on usage
  if [ "$used_int" -ge 80 ]; then
    bar_color='\033[91m'   # bright red
  elif [ "$used_int" -ge 50 ]; then
    bar_color='\033[93m'   # bright yellow
  else
    bar_color='\033[92m'   # bright green
  fi

  # Build the bar
  bar=""
  i=0; while [ "$i" -lt "$filled" ]; do bar="${bar}█"; i=$((i+1)); done
  i=0; while [ "$i" -lt "$empty" ]; do bar="${bar}░"; i=$((i+1)); done

  printf " ${DIM}|${RESET} ${bar_color}✻${RESET} ${bar_color}%s${RESET} ${DIM}%d%%${RESET}" "$bar" "$used_int"
fi

# --- 5. Token counts (Blue in / Indigo out) ---
if [ -n "$total_in" ] && [ -n "$total_out" ]; then
  fmt_tokens() {
    val=$1
    if [ "$val" -ge 1000000 ]; then
      awk -v n="$val" 'BEGIN { printf "%.1fM", n/1000000 }'
    elif [ "$val" -ge 1000 ]; then
      awk -v n="$val" 'BEGIN { printf "%.1fk", n/1000 }'
    else
      printf '%d' "$val"
    fi
  }
  in_fmt=$(fmt_tokens "$total_in")
  out_fmt=$(fmt_tokens "$total_out")
  printf " ${DIM}|${RESET} ${BLUE}\xE2\xAC\x87 %s${RESET}${DIM}in${RESET} ${INDIGO}\xE2\xAC\x86 %s${RESET}${DIM}out${RESET}" "$in_fmt " "$out_fmt "
fi

# --- 6. Usage — S: session (5h)   W: week (7d, all models) ---
# Minimal labels: one coloured capital letter each (S cyan, W pink), with the % value in
# grey (DIM) to match the context-window %. Session and week split by a dim | delimiter.
# Note: the statusline JSON only exposes five_hour + seven_day rate limits — there is
# no per-model figure, so a "Fable weekly" (F) value can't be shown until Claude Code adds it.
if [ -n "$session_used" ] || [ -n "$week_used" ]; then
  printf " ${DIM}|${RESET}"
  [ -n "$session_used" ] && printf " ${CYAN}S${RESET} ${DIM}%d%%${RESET}" "$(printf '%.0f' "$session_used")"
  [ -n "$session_used" ] && [ -n "$week_used" ] && printf " ${DIM}|${RESET}"
  [ -n "$week_used" ]    && printf " ${PINK}W${RESET} ${DIM}%d%%${RESET}" "$(printf '%.0f' "$week_used")"
fi
