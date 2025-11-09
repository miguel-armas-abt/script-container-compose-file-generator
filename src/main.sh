#!/bin/bash
set -e

source ./commons.sh

# Forward console output to a log file
: > "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1

print_title() {
  echo -e "\n########## ${CYAN} Execute an action ${NC}##########\n"
}

script_caller() {
  $1
  print_title
}

print_title

options=(
  "Generate docker compose file"
  "Exit"
)

while true; do
  select option in "${options[@]}"; do
      case $REPLY in
        1) script_caller "./docker-compose-file-generator.sh"; break ;;
        2) exit; ;;
        *) echo -e "${RED}Invalid option${NC}" >&2
      esac
  done
  sed -i -r "$ANSI_REGEX" "$LOG_FILE" || true
done