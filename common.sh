#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Kleuren
C_RESET="\033[0m"
C_RED="\033[31m"
C_GREEN="\033[32m"
C_YELLOW="\033[33m"
C_BLUE="\033[34m"

log_info()   { printf "${C_BLUE}[INFO]${C_RESET} %s\n" "$*"; }
log_warn()   { printf "${C_YELLOW}[WARN]${C_RESET} %s\n" "$*"; }
log_error()  { printf "${C_RED}[ERROR]${C_RESET} %s\n" "$*"; }
log_success(){ printf "${C_GREEN}[ OK ]${C_RESET} %s\n" "$*"; }

command_exists() {
  command -v "$1" >/dev/null 2>&1
}