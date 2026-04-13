#!/usr/bin/env bash
set -o errexit
set -o pipefail
set -o nounset

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/common.sh"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/bootstrap.conf"

ZSHRC_PATH="${HOME}/.zshrc"
ZSHRC_DIR="${SCRIPT_DIR}/zshrc"
ZSHRC_ALIAS_DIR="${ZSHRC_DIR}/aliases"
ZSHRC_ALIAS_FILE="${ZSHRC_ALIAS_DIR}/aliases.zsh"
ZSHRC_PLUGIN_SNIPPETS_DIR="${ZSHRC_DIR}/plugins"

usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  --dotfiles                Install dotfiles using stow (default packages list)
  --dotfiles-packages LIST  Comma-separated list of stow packages to install
                            (e.g.: zsh,git,nvim)

  --apps                    Install applications via Homebrew / scripts for ALL
                            default packages and default Oh My Zsh plugins
  --apps-packages LIST      Comma-separated list of package names for which to
                            install applications and/or Oh My Zsh plugins
                            (e.g.: zsh,git,ohmyzsh,zsh-syntax-highlighting)

  --zsh-aliases             Append a managed alias block in ~/.zshrc that sources
                            global aliases and per-app aliases (requires oh-my-zsh)
  --zsh-extend              Process zshrc snippets for apps (zshrc/<app>/config.zsh),
                            asking per app whether to append to ~/.zshrc
                            (requires oh-my-zsh)

  --all                     Install:
                              - ALL dotfiles (DEFAULT_PACKAGES)
                              - ALL applications (DEFAULT_PACKAGES)
                              - oh-my-zsh (via local script)
                              - default Oh My Zsh plugins (ZSH_PLUGIN_DEFAULTS)
                              - zsh snippets for all packages
                              - zsh alias block

  -h, --help                Show this help message and exit
EOF
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

install_homebrew_if_needed() {
  if command_exists brew; then
    log_info "Homebrew is already installed."
    return
  fi

  log_info "Homebrew not found, starting installation..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if [[ "$OSTYPE" == "darwin"* ]]; then
    if [[ -d "/opt/homebrew/bin" ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -d "/usr/local/bin" ]]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  else
    if [[ -d "$HOME/.linuxbrew" ]]; then
      eval "$("$HOME/.linuxbrew/bin/brew" shellenv)"
    elif [[ -d "/home/linuxbrew/.linuxbrew" ]]; then
      eval "$("/home/linuxbrew/.linuxbrew/bin/brew" shellenv)"
    fi
  fi

  if ! command_exists brew; then
    log_error "Homebrew installation appears to have failed or brew is not in PATH."
    exit 1
  fi

  log_success "Homebrew installed and available."
}

install_stow_via_brew_if_needed() {
  if command_exists stow; then
    log_info "stow is already installed."
    return
  fi

  log_info "stow is not installed. Installing via Homebrew..."
  install_homebrew_if_needed
  brew install stow

  if ! command_exists stow; then
    log_error "stow installation failed or stow is not in PATH."
    exit 1
  fi

  log_success "stow installed via Homebrew."
}

###############################################################################
# Oh My Zsh installation (via local script)
###############################################################################
ohmyzsh_installed() {
  [[ -d "${HOME}/.oh-my-zsh" ]]
}

install_ohmyzsh_if_needed() {
  if ohmyzsh_installed; then
    log_info "Oh My Zsh is already installed at ~/.oh-my-zsh."
    return
  fi

  if ! command_exists zsh; then
    log_info "zsh not found, installing via Homebrew first..."
    install_homebrew_if_needed
    brew install zsh
  fi

  local installer="${SCRIPT_DIR}/ohmyzsh/install.sh"
  if [[ ! -x "${installer}" ]]; then
    if [[ -f "${installer}" ]]; then
      log_error "Oh My Zsh installer script exists but is not executable: ${installer}"
    else
      log_error "Oh My Zsh installer script not found at: ${installer}"
    fi
    log_error "Please place an executable install.sh at ${installer}"
    exit 1
  fi

  log_info "Installing Oh My Zsh via ${installer}..."
  RUNZSH=no KEEP_ZSHRC=yes "${installer}"
  log_success "Oh My Zsh installed."
}

###############################################################################
# Package -> brew formula mapping
###############################################################################
get_brew_packages_for() {
  local name="$1"
  case "$name" in
    zsh)       echo "zsh" ;;
    git)       echo "git" ;;
    nvim|neovim)
               echo "neovim" ;;
    tmux)      echo "tmux" ;;
    starship)  echo "starship" ;;
    ghostty)   echo "ghostty" ;;
    curl)      echo "curl" ;;
    eza)       echo "eza" ;;
    meslo-nerd-font)  echo "font-meslo-lg-nerd-font" ;;
    ohmyzsh)   echo "" ;;   # installed via script, not via brew
    *)
      echo ""
      ;;
  esac
}

###############################################################################
# Oh My Zsh plugins via modular scripts
###############################################################################
install_ohmyzsh_plugins() {
  local plugins=("$@")
  if [[ "${#plugins[@]}" -eq 0 ]]; then
    return
  fi

  if ! ohmyzsh_installed; then
    log_info "Oh My Zsh not detected; installing first..."
    install_ohmyzsh_if_needed
  fi

  local plugin_script_dir="${SCRIPT_DIR}/ohmyzsh/plugins"
  local p
  for p in "${plugins[@]}"; do
    local script="${plugin_script_dir}/${p}.sh"
    if [[ ! -x "${script}" ]]; then
      if [[ -f "${script}" ]]; then
        log_warn "Plugin installer script for '${p}' exists but is not executable: ${script}"
      else
        log_warn "Plugin installer script for '${p}' not found at: ${script}"
      fi
      continue
    fi
    log_info "Running Oh My Zsh plugin installer for '${p}' via ${script}..."
    "${script}"
    log_success "Plugin '${p}' installation script completed."
  done
}

###############################################################################
# Ensure ~/.zshrc exists (only when oh-my-zsh is present)
###############################################################################
ensure_zshrc_exists() {
  if ! ohmyzsh_installed; then
    log_warn "Oh My Zsh is not installed; skipping .zshrc creation."
    return
  fi
  if [[ -f "${ZSHRC_PATH}" ]]; then
    return
  fi
  log_info "No ~/.zshrc found, creating a minimal one."
  cat > "${ZSHRC_PATH}" <<'EOF'
# Managed by bootstrap
# Add your customizations below.
EOF
}

###############################################################################
# Update plugins=(...) in .zshrc
###############################################################################
ensure_plugins_in_zshrc() {
  local plugins_to_add=("$@")
  if [[ "${#plugins_to_add[@]}" -eq 0 ]]; then
    return
  fi
  if ! ohmyzsh_installed; then
    log_warn "Oh My Zsh is not installed; skipping plugins=(...) update."
    return
  fi

  ensure_zshrc_exists
  if [[ ! -f "${ZSHRC_PATH}" ]]; then
    log_warn "No ~/.zshrc found, cannot update plugins array."
    return
  fi

  local current_line
  current_line="$(grep -E '^[[:space:]]*plugins=\(' "${ZSHRC_PATH}" | head -n1 || true)"
  local all_plugins=()

  if [[ -n "${current_line}" ]]; then
    local inner
    inner="$(echo "${current_line}" | sed -E 's/^[[:space:]]*plugins=\((.*)\).*/\1/')"
    read -r -a all_plugins <<< "${inner}"
  fi

  local p existing
  for p in "${plugins_to_add[@]}"; do
    local exists=0
    for existing in "${all_plugins[@]}"; do
      if [[ "${existing}" == "${p}" ]]; then
        exists=1
        break
      fi
    done
    if [[ "${exists}" -eq 0 ]]; then
      all_plugins+=("${p}")
    fi
  done

  if [[ "${#all_plugins[@]}" -eq 0 ]]; then
    all_plugins=("git")
  fi

  local new_line="plugins=(${all_plugins[*]})"

  if [[ -n "${current_line}" ]]; then
    local tmp
    tmp="$(mktemp)"
    sed -E "s|^[[:space:]]*plugins=\(.*\).*|${new_line}|" "${ZSHRC_PATH}" > "${tmp}"
    mv "${tmp}" "${ZSHRC_PATH}"
  else
    {
      echo ""
      echo "# Managed plugins list (extended by bootstrap)"
      echo "${new_line}"
    } >> "${ZSHRC_PATH}"
  fi

  log_success "Updated plugins array in ${ZSHRC_PATH} to: ${new_line}"
}

###############################################################################
# Per-plugin snippet in .zshrc
###############################################################################
append_plugin_snippet_to_zshrc() {
  local plugin_name="$1"
  if ! ohmyzsh_installed; then
    log_warn "Oh My Zsh is not installed; skipping plugin snippet for '${plugin_name}'."
    return
  fi

  local snippet_file="${ZSHRC_PLUGIN_SNIPPETS_DIR}/${plugin_name}.zsh"
  if [[ ! -f "${snippet_file}" ]]; then
    log_info "No snippet file found for plugin '${plugin_name}' at ${snippet_file}, skipping snippet append."
    return
  fi

  ensure_zshrc_exists

  log_info "Proposed snippet for plugin '${plugin_name}' (from ${snippet_file}):"
  echo "----------------------------------------"
  cat "${snippet_file}"
  echo "----------------------------------------"

  local answer
  read -r -p "Do you want to append this plugin snippet to ${ZSHRC_PATH}? [y/N] " answer
  case "${answer}" in
    y|Y|yes|YES)
      {
        echo ""
        echo "# BEGIN plugin ${plugin_name} snippet (managed by bootstrap)"
        cat "${snippet_file}"
        echo "# END plugin ${plugin_name} snippet (managed by bootstrap)"
      } >> "${ZSHRC_PATH}"
      log_success "Snippet for plugin '${plugin_name}' appended to ${ZSHRC_PATH}."
      ;;
    *)
      log_info "Skipping snippet append for plugin '${plugin_name}'."
      ;;
  esac
}

###############################################################################
# Apps installation via Homebrew / scripts / plugins
###############################################################################
install_apps_for_packages() {
  local packages=("$@")

  # Install oh-my-zsh if explicitly requested
  local pkg
  for pkg in "${packages[@]}"; do
    if [[ "${pkg}" == "ohmyzsh" ]]; then
      install_ohmyzsh_if_needed
      break
    fi
  done

  # Split plugin names vs normal packages
  local plugin_pkgs=()
  local non_plugin_pkgs=()
  for pkg in "${packages[@]}"; do
    if [[ " ${ZSH_PLUGIN_DEFAULTS[*]} " == *" ${pkg} "* ]]; then
      plugin_pkgs+=("${pkg}")
    else
      non_plugin_pkgs+=("${pkg}")
    fi
  done

  # Install plugins (ensures oh-my-zsh is present)
  if [[ "${#plugin_pkgs[@]}" -gt 0 ]]; then
    log_info "Installing Oh My Zsh plugins via scripts: ${plugin_pkgs[*]}"
    install_ohmyzsh_plugins "${plugin_pkgs[@]}"
    ensure_plugins_in_zshrc "${plugin_pkgs[@]}"
    local p
    for p in "${plugin_pkgs[@]}"; do
      append_plugin_snippet_to_zshrc "${p}"
    done
  fi

  # Now only handle non-plugin packages via Homebrew
  packages=("${non_plugin_pkgs[@]}")

  install_homebrew_if_needed

  # Ensure zsh is installed first, if requested
  local ordered_packages=()
  local seen_zsh=0
  for pkg in "${packages[@]}"; do
    if [[ "${pkg}" == "zsh" ]]; then
      ordered_packages+=("zsh")
      seen_zsh=1
      break
    fi
  done
  for pkg in "${packages[@]}"; do
    if [[ "${pkg}" != "zsh" && "${pkg}" != "ohmyzsh" ]]; then
      ordered_packages+=("${pkg}")
    fi
  done
  if [[ "${seen_zsh}" -eq 0 ]]; then
    ordered_packages=()
    for pkg in "${packages[@]}"; do
      if [[ "${pkg}" != "ohmyzsh" ]]; then
        ordered_packages+=("${pkg}")
      fi
    done
  fi

  for pkg in "${ordered_packages[@]}"; do
    local brew_pkgs
    brew_pkgs="$(get_brew_packages_for "${pkg}")"
    if [[ -z "${brew_pkgs}" ]]; then
      log_warn "No brew mapping for package '${pkg}', skipping."
      continue
    fi
    log_info "Installing Homebrew packages for '${pkg}': ${brew_pkgs}"
    # shellcheck disable=SC2086
    brew install ${brew_pkgs} || log_warn "Failed to install some packages for '${pkg}'."
    log_success "Finished installation for '${pkg}'."
  done
}

install_apps_for_all_default_packages() {
  install_apps_for_packages "${DEFAULT_PACKAGES[@]}"
}

###############################################################################
# Ensure ~/.config exists
###############################################################################
ensure_config_dir_exists() {
  if [[ ! -d "${HOME}/.config" ]]; then
    log_info "No ~/.config directory found, creating it."
    mkdir -p "${HOME}/.config"
  fi
}

###############################################################################
# Dotfiles installation via stow
###############################################################################
install_dotfiles_with_stow() {
  local packages=("$@")

  install_stow_via_brew_if_needed
  ensure_config_dir_exists

  local pkg
  for pkg in "${packages[@]}"; do
    if [[ -d "${SCRIPT_DIR}/${pkg}" ]]; then
      log_info "Applying stow package '${pkg}'..."
      stow --dir="${SCRIPT_DIR}" --target="${HOME}" "${pkg}"
      log_success "Stow package '${pkg}' installed."
    else
      log_warn "Stow package directory '${pkg}' does not exist, skipping."
    fi
  done
}

###############################################################################
# Zsh helpers: app snippets and aliases
###############################################################################
append_snippet_to_zshrc_with_prompt() {
  local app_name="$1"
  local snippet_file="$2"

  if [[ ! -f "${snippet_file}" ]]; then
    log_warn "No zsh snippet found for '${app_name}' at ${snippet_file}, skipping."
    return
  fi
  if ! ohmyzsh_installed; then
    log_warn "Oh My Zsh is not installed; skipping zsh snippet integration."
    return
  fi

  ensure_zshrc_exists

  log_info "Proposed zsh snippet for '${app_name}' (from ${snippet_file}):"
  echo "----------------------------------------"
  cat "${snippet_file}"
  echo "----------------------------------------"

  local answer
  read -r -p "Append this snippet to ${ZSHRC_PATH}? [y/N] " answer
  case "${answer}" in
    y|Y|yes|YES)
      {
        echo ""
        echo "# BEGIN ${app_name} snippet (managed by bootstrap)"
        cat "${snippet_file}"
        echo "# END ${app_name} snippet (managed by bootstrap)"
      } >> "${ZSHRC_PATH}"
      log_success "Snippet for '${app_name}' appended to ${ZSHRC_PATH}."
      ;;
    *)
      log_info "Skipping snippet append for '${app_name}'."
      ;;
  esac
}

append_alias_block_in_zshrc() {
  if ! ohmyzsh_installed; then
    log_warn "Oh My Zsh is not installed; skipping zsh alias block."
    return
  fi
  ensure_zshrc_exists

  local begin_marker="# BEGIN ALIASES (managed by bootstrap)"
  local end_marker="# END ALIASES (managed by bootstrap)"
  if grep -q "${begin_marker}" "${ZSHRC_PATH}" && grep -q "${end_marker}" "${ZSHRC_PATH}"; then
    log_info "Managed alias block already present in ${ZSHRC_PATH}, skipping re-append."
    return
  fi

  {
    echo ""
    echo "${begin_marker}"
    echo "# This block is auto-generated; it sources aliases managed in the repo."
    echo "# Global aliases:"
    echo "if [ -f \"${ZSHRC_ALIAS_FILE}\" ]; then"
    echo "  source \"${ZSHRC_ALIAS_FILE}\""
    echo "fi"
    echo ""
    echo "# Per-application aliases:"
    echo "# For each app in DEFAULT_PACKAGES we attempt to source:"
    echo "#   ${ZSHRC_DIR}/<app>/aliases.zsh"
    echo "for app in ${DEFAULT_PACKAGES[*]}; do"
    echo "  alias_file=\"${ZSHRC_DIR}/\${app}/aliases.zsh\""
    echo "  if [ -f \"\${alias_file}\" ]; then"
    echo "    source \"\${alias_file}\""
    echo "  fi"
    echo "done"
    echo "${end_marker}"
  } >> "${ZSHRC_PATH}"

  log_success "Alias block appended to ${ZSHRC_PATH}."
}

process_zsh_snippets_for_packages() {
  local packages=("$@")
  if ! ohmyzsh_installed; then
    log_warn "Oh My Zsh is not installed; skipping zsh snippet integration."
    return
  fi
  if ! command_exists zsh; then
    log_warn "zsh is not installed, skipping zsh snippet integration."
    return
  fi

  local pkg
  for pkg in "${packages[@]}"; do
    local snippet_dir="${ZSHRC_DIR}/${pkg}"
    local snippet_file="${snippet_dir}/config.zsh"
    if [[ -f "${snippet_file}" ]]; then
      append_snippet_to_zshrc_with_prompt "${pkg}" "${snippet_file}"
    fi
  done
}

###############################################################################
# Main
###############################################################################
main() {
  local do_dotfiles=0
  local do_apps=0
  local use_default_dotfiles=0
  local use_default_apps=0
  local custom_dotfiles=""
  local custom_apps=""
  local do_zsh_aliases=0
  local do_zsh_extend=0

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dotfiles)
        do_dotfiles=1
        use_default_dotfiles=1
        shift
        ;;
      --dotfiles-packages)
        if [[ $# -lt 2 ]]; then
          log_error "Missing argument for --dotfiles-packages."
          usage
          exit 1
        fi
        do_dotfiles=1
        custom_dotfiles="$2"
        shift 2
        ;;
      --apps)
        do_apps=1
        use_default_apps=1
        shift
        ;;
      --apps-packages)
        if [[ $# -lt 2 ]]; then
          log_error "Missing argument for --apps-packages."
          usage
          exit 1
        fi
        do_apps=1
        custom_apps="$2"
        shift 2
        ;;
      --zsh-aliases)
        do_zsh_aliases=1
        shift
        ;;
      --zsh-extend)
        do_zsh_extend=1
        shift
        ;;
      --all)
        do_dotfiles=1
        do_apps=1
        use_default_dotfiles=1
        use_default_apps=1
        do_zsh_aliases=1
        do_zsh_extend=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        log_error "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
  done

  if [[ "${do_dotfiles}" -eq 0 && "${do_apps}" -eq 0 && "${do_zsh_aliases}" -eq 0 && "${do_zsh_extend}" -eq 0 ]]; then
    log_warn "No actions specified."
    usage
    exit 1
  fi

  local apps_to_install=()

  # Apps
  if [[ "${do_apps}" -eq 1 ]]; then
    if [[ -n "${custom_apps}" ]]; then
      IFS=',' read -r -a apps_to_install <<< "${custom_apps}"
    elif [[ "${use_default_apps}" -eq 1 ]]; then
      apps_to_install=("${DEFAULT_PACKAGES[@]}")
      apps_to_install+=("${ZSH_PLUGIN_DEFAULTS[@]}")
      # ensure ohmyzsh is in the list
      if [[ ! " ${apps_to_install[*]} " =~ \ ohmyzsh\  ]]; then
        apps_to_install+=("ohmyzsh")
      fi
    fi

    if [[ "${#apps_to_install[@]}" -gt 0 ]]; then
      install_apps_for_packages "${apps_to_install[@]}"
    else
      log_info "No packages selected for apps installation."
    fi
  fi

  # Dotfiles
  local dotfiles_to_install=()
  if [[ "${do_dotfiles}" -eq 1 ]]; then
    if [[ -n "${custom_dotfiles}" ]]; then
      IFS=',' read -r -a dotfiles_to_install <<< "${custom_dotfiles}"
    elif [[ "${use_default_dotfiles}" -eq 1 ]]; then
      dotfiles_to_install=("${DEFAULT_PACKAGES[@]}")
    fi

    local filtered_dotfiles=()
    local df
    for df in "${dotfiles_to_install[@]}"; do
      if [[ "${df}" != "ohmyzsh" ]]; then
        filtered_dotfiles+=("${df}")
      fi
    done

    if [[ "${#filtered_dotfiles[@]}" -gt 0 ]]; then
      install_dotfiles_with_stow "${filtered_dotfiles[@]}"
    else
      log_info "No stow packages selected. Nothing to do for dotfiles."
    fi
  fi

  # Zsh snippets
  if [[ "${do_zsh_extend}" -eq 1 ]]; then
    if [[ "${#apps_to_install[@]}" -eq 0 ]]; then
      apps_to_install=("${DEFAULT_PACKAGES[@]}")
    fi
    process_zsh_snippets_for_packages "${apps_to_install[@]}"
  fi

  # Zsh aliases
  if [[ "${do_zsh_aliases}" -eq 1 ]]; then
    append_alias_block_in_zshrc
  fi
}

main "$@"