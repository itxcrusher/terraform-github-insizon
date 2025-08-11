#!/usr/bin/env bash
# Interactive menu to run common tasks.
# Allows selecting an environment and running fmt, plan, apply, output, destroy, push.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

select_environment() {
  local env
  PS3="Select environment (1=dev, 2=qa, 3=prod, 4=Quit): "
  select env in dev qa prod "Quit"; do
    case "$env" in
      dev|qa|prod)
        # Return just the value
        printf "%s" "$env"
        return 0
        ;;
      "Quit")
        exit 0
        ;;
      *)
        echo "Invalid selection."
        ;;
    esac
  done
}

main_menu() {
  local env choice
  env="$(select_environment)"

  while true; do
    echo
    echo "Environment: $env"
    PS3="Choose an action: "
    select choice in "Format (fmt)" "Plan" "Apply" "Output" "Destroy" "Push" "Change Env" "Quit"; do
      case "$REPLY" in
        1) bash "$SCRIPT_DIR/fmt.sh"; break ;;
        2) bash "$SCRIPT_DIR/plan.sh"  "$env"; break ;;
        3) bash "$SCRIPT_DIR/apply.sh" "$env"; break ;;
        4)
           read -r -p "Output name (empty for all): " out_name
           if [[ -z "$out_name" ]]; then
             bash "$SCRIPT_DIR/output.sh" "$env"
           else
             bash "$SCRIPT_DIR/output.sh" "$env" "$out_name"
           fi
           break
           ;;
        5) bash "$SCRIPT_DIR/destroy.sh" "$env"; break ;;
        6) bash "$SCRIPT_DIR/push.sh"; break ;;
        7) env="$(select_environment)"; break ;;
        8) exit 0 ;;
        *) echo "Invalid option."; continue ;;
      esac
    done
  done
}

main_menu
