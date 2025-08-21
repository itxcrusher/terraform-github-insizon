#!/usr/bin/env bash
# Interactive menu to run common tasks.
# Back always returns exactly one level up.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname "$0")" >/dev/null 2>&1 && pwd)"

# Print to stderr to avoid stdout buffering issues on MSYS/MINGW.
print_env_menu() {
  {
    echo
    echo "Select environment:"
    echo "1) dev"
    echo "2) qa"
    echo "3) prod"
    echo "4) Back"
  } >&2
}

# Select environment.
# Returns selected env on stdout.
# Exit status:
#   0 -> env chosen
#   1 -> user chose Back
select_environment() {
  local choice
  while true; do
    print_env_menu
    read -r -p "Enter choice: " choice
    case "$choice" in
      1) printf "dev";  return 0 ;;
      2) printf "qa";   return 0 ;;
      3) printf "prod"; return 0 ;;
      4) return 1 ;;  # Back
      *) echo "Invalid selection." >&2 ;;
    esac
  done
}

github_menu() {
  local choice
  while true; do
    {
      echo
      echo "GitHub Automation:"
      echo "1) Dry-run all"
      echo "2) Bootstrap (live)"
      echo "3) Repos"
      echo "4) Secrets"
      echo "5) Keys"
      echo "6) Org hooks"
      echo "7) Teams"
      echo "8) Users"
      echo "9) GPG"
      echo "10) Back"
    } >&2
    read -r -p "Choose an action: " choice
    case "$choice" in
      1) bash "$SCRIPT_DIR/github.sh" dry-run ;;
      2) bash "$SCRIPT_DIR/github.sh" bootstrap ;;
      3) bash "$SCRIPT_DIR/github.sh" repos --live ;;
      4) bash "$SCRIPT_DIR/github.sh" secrets --live ;;
      5) bash "$SCRIPT_DIR/github.sh" keys --live ;;
      6) bash "$SCRIPT_DIR/github.sh" orghooks --live ;;
      7) bash "$SCRIPT_DIR/github.sh" teams --live ;;
      8) bash "$SCRIPT_DIR/github.sh" users --live ;;
      9) bash "$SCRIPT_DIR/github.sh" gpg --live ;;
      10) return 0 ;;   # Back -> one level up (Main Menu)
      *) echo "Invalid option." >&2 ;;
    esac
  done
}

terraform_menu() {
  local env choice

  # Initial env select. If Back, go one level up (Main Menu).
  if ! env="$(select_environment)"; then
    return 0
  fi

  while true; do
    {
      echo
      echo "Terraform | Environment: $env"
      echo "1) Format (fmt)"
      echo "2) Plan"
      echo "3) Apply"
      echo "4) Output"
      echo "5) Destroy"
      echo "6) Push"
      echo "7) Change Env"
      echo "8) Back"
    } >&2
    read -r -p "Choose an action: " choice
    case "$choice" in
      1) bash "$SCRIPT_DIR/fmt.sh" ;;
      2) bash "$SCRIPT_DIR/plan.sh"  "$env" ;;
      3) bash "$SCRIPT_DIR/apply.sh" "$env" ;;
      4)
         read -r -p "Output name (empty for all): " out_name
         if [[ -z "$out_name" ]]; then
           bash "$SCRIPT_DIR/output.sh" "$env"
         else
           bash "$SCRIPT_DIR/output.sh" "$env" "$out_name"
         fi
         ;;
      5) bash "$SCRIPT_DIR/destroy.sh" "$env" ;;
      6) bash "$SCRIPT_DIR/push.sh" ;;
      7)
         # Change Env: if Back here, stay in Terraform menu (one level up).
         if env_new="$(select_environment)"; then
           env="$env_new"
         fi
         ;;
      8) return 0 ;;   # Back -> one level up (Main Menu)
      *) echo "Invalid option." >&2 ;;
    esac
  done
}

main_menu() {
  local choice
  while true; do
    {
      echo
      echo "Main Menu:"
      echo "1) Terraform"
      echo "2) GitHub Automation"
      echo "3) Quit"
    } >&2
    read -r -p "Choose a domain: " choice
    case "$choice" in
      1) terraform_menu ;;  # Back returns here
      2) github_menu ;;     # Back returns here
      3) exit 0 ;;
      *) echo "Invalid option." >&2 ;;
    esac
  done
}

main_menu
