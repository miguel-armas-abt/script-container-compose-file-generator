#!/bin/bash

source ./../variables.env

ANSI_REGEX=$'s/\\x1B\\[[0-9;]*[A-Za-z]//g'

#colors
RED='\033[0;31m'
NC='\033[0m' #no color
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'

#symbols
CHECK_SYMBOL="\033[0;32m\xE2\x9C\x94\033[0m"
WRENCH_SYMBOL="\xE2\x9C\xA8"

#timestamps
function get_timestamp {
    date +"%l:%M:%S:%3N%p"
}

function print_log {
  local command=$1
  echo "$(get_timestamp) .......... $command" >&2
}

function print_title {
  local title="$1"
  local width=${2:-80}
  local color="${3:-$PURPLE}"

  local border_line
  border_line=$(printf '%*s' "$width" '' | tr ' ' '*')

  local padding=$(( (width - ${#title} - 2) / 2 ))
  local line
  line="$(printf '*%*s%s%*s*' "$padding" '' "$title" "$padding" '')"

  line="${line:0:$((width-1))}*"

  echo -e "${color}${border_line}${NC}"
  echo -e "${color}${line}${NC}"
  echo -e "${color}${border_line}${NC}"
  echo "" >&2
}

function arrow_loader {
  local message="$1"
  local arrows=("←" "↖" "↑" "↗" "→" "↘" "↓" "↙")

  if [[ -z "$ARROW_INDEX" ]]; then
    ARROW_INDEX=0
  fi

  printf "\r${CYAN}%s${NC} %s" "${arrows[ARROW_INDEX]}" "$message"
  ARROW_INDEX=$(( (ARROW_INDEX + 1) % ${#arrows[@]} ))
}