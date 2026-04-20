#!/usr/bin/env bash
set -euo pipefail

# OTTO - Installation Script
# This script sets up OTTO configuration directory and detects available tools.

OTTO_HOME="${OTTO_HOME:-${HOME}/.config/otto}"
OTTO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OTTO_VERSION="0.1.0"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

print_banner() {
    echo -e "${CYAN}"
    echo "  ___  _____ _____ ___  "
    echo " / _ \\|_   _|_   _/ _ \\ "
    echo "| | | | | |   | || | | |"
    echo "| |_| | | |   | || |_| |"
    echo " \\___/  |_|   |_| \\___/ "
    echo ""
    echo -e "${NC}${BOLD}Operations & Technology Toolchain Orchestrator${NC}"
    echo -e "Version ${OTTO_VERSION}"
    echo ""
}

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

check_prerequisites() {
    local missing=0

    echo -e "\n${BOLD}Checking prerequisites...${NC}\n"

    if command -v jq &>/dev/null; then
        log_ok "jq $(jq --version 2>/dev/null || echo 'found')"
    else
        log_error "jq not found - install with: sudo apt install jq / brew install jq"
        missing=1
    fi

    if command -v yq &>/dev/null; then
        log_ok "yq $(yq --version 2>/dev/null | head -1 || echo 'found')"
    else
        log_warn "yq not found - install with: sudo apt install yq / brew install yq"
        log_warn "yq is optional but recommended for YAML config management"
    fi

    if command -v curl &>/dev/null; then
        log_ok "curl found"
    else
        log_error "curl not found - install with: sudo apt install curl / brew install curl"
        missing=1
    fi

    if [ "${missing}" -eq 1 ]; then
        echo ""
        log_error "Missing required dependencies. Please install them and re-run."
        exit 1
    fi
}

detect_tools() {
    echo -e "\n${BOLD}Detecting installed DevOps tools...${NC}\n"

    local tools_found=0
    local tools_json="{}"

    declare -A tool_map=(
        # IaC
        ["terraform"]="iac"
        ["tofu"]="iac"
        ["ansible"]="iac"
        ["ansible-playbook"]="iac"
        # CI/CD
        ["gh"]="cicd"
        ["glab"]="cicd"
        ["jenkins-cli"]="cicd"
        ["argocd"]="cicd"
        # Containers
        ["docker"]="containers"
        ["podman"]="containers"
        ["kubectl"]="containers"
        ["helm"]="containers"
        ["k3s"]="containers"
        ["k0s"]="containers"
        # Cloud
        ["aws"]="cloud"
        ["gcloud"]="cloud"
        ["az"]="cloud"
        ["doctl"]="cloud"
        ["hcloud"]="cloud"
        # Monitoring
        ["promtool"]="monitoring"
        ["logcli"]="monitoring"
        ["zabbix_sender"]="monitoring"
        # Security
        ["vault"]="security"
        ["trivy"]="security"
        ["sops"]="security"
        ["kubeseal"]="security"
        ["falcoctl"]="security"
        # Database
        ["psql"]="database"
        ["mysql"]="database"
        ["mongosh"]="database"
        ["redis-cli"]="database"
        # Git
        ["git"]="git"
        # Web servers
        ["nginx"]="webserver"
        ["apache2"]="webserver"
        ["httpd"]="webserver"
        ["caddy"]="webserver"
        # Networking
        ["openssl"]="networking"
        ["certbot"]="networking"
        ["wg"]="networking"
        ["openvpn"]="networking"
        ["ssh"]="networking"
        ["rsync"]="networking"
        # Backup
        ["restic"]="backup"
        ["borg"]="backup"
        ["velero"]="backup"
        # Scripting
        ["python3"]="scripting"
        ["go"]="scripting"
        ["pwsh"]="scripting"
        ["make"]="scripting"
    )

    for tool in "${!tool_map[@]}"; do
        if command -v "${tool}" &>/dev/null; then
            local version
            version=$("${tool}" --version 2>/dev/null | head -1 || echo "found")
            log_ok "${tool} - ${version}"
            tools_found=$((tools_found + 1))
            tools_json=$(echo "${tools_json}" | jq --arg t "${tool}" --arg c "${tool_map[$tool]}" '.[$c] += [$t]')
        fi
    done

    echo ""
    log_info "Detected ${tools_found} tools"

    # Save detected tools
    mkdir -p "${OTTO_HOME}"
    echo "${tools_json}" | jq '.' > "${OTTO_HOME}/detected-tools.json"
}

choose_profile() {
    # All menu output goes to stderr so $(choose_profile) only captures the result
    echo -e "\n${BOLD}Choose your permission profile:${NC}\n" >&2
    echo -e "  ${GREEN}1) beginner${NC}" >&2
    echo -e "     Best for: People learning DevOps" >&2
    echo -e "     OTTO explains every command before running it, suggests best" >&2
    echo -e "     practices, warns about mistakes. All actions require approval." >&2
    echo -e "     Read: ${YELLOW}ask${NC}  |  Write: ${YELLOW}ask${NC}  |  Destroy: ${RED}deny${NC}" >&2
    echo "" >&2
    echo -e "  ${BLUE}2) balanced${NC} ${DIM}(recommended)${NC}" >&2
    echo -e "     Best for: Daily DevOps work" >&2
    echo -e "     Read operations run automatically, write operations ask for" >&2
    echo -e "     confirmation, destructive operations are blocked." >&2
    echo -e "     Read: ${GREEN}auto${NC}  |  Write: ${YELLOW}confirm${NC}  |  Destroy: ${RED}deny${NC}" >&2
    echo "" >&2
    echo -e "  ${YELLOW}3) autonomous${NC}" >&2
    echo -e "     Best for: Development environments only" >&2
    echo -e "     Maximum automation with minimal confirmations. OTTO acts" >&2
    echo -e "     first and reports back. NOT recommended for production." >&2
    echo -e "     Read: ${GREEN}auto${NC}  |  Write: ${GREEN}auto${NC}  |  Destroy: ${YELLOW}confirm${NC}" >&2
    echo "" >&2
    echo -e "  ${RED}4) paranoid${NC}" >&2
    echo -e "     Best for: Production systems, compliance environments" >&2
    echo -e "     Everything requires explicit approval. No automatic actions." >&2
    echo -e "     Maximum safety at the cost of speed." >&2
    echo -e "     Read: ${YELLOW}confirm${NC}  |  Write: ${YELLOW}suggest${NC}  |  Destroy: ${RED}deny${NC}" >&2
    echo "" >&2

    local choice
    read -r -p "Select profile [1-4, default=2]: " choice
    choice="${choice:-2}"

    case "${choice}" in
        1) echo "beginner" ;;
        2) echo "balanced" ;;
        3) echo "autonomous" ;;
        4) echo "paranoid" ;;
        *) echo "balanced" ;;
    esac
}

setup_config_dir() {
    echo -e "\n${BOLD}Setting up OTTO configuration...${NC}\n"

    # Create directory structure
    mkdir -p "${OTTO_HOME}"/{agents,knowledge,state/{tasks/{triage,todo,in-progress,done,failed,cancelled},memory/{projects,people,decisions,learnings,runbooks},night-watch}}

    # Copy default config if none exists
    if [ ! -f "${OTTO_HOME}/config.yaml" ]; then
        local profile
        profile=$(choose_profile)
        log_info "Using profile: ${profile}"

        if [ -f "${OTTO_DIR}/config/profiles/${profile}.yaml" ]; then
            cp "${OTTO_DIR}/config/profiles/${profile}.yaml" "${OTTO_HOME}/config.yaml"
        else
            cp "${OTTO_DIR}/config/default.yaml" "${OTTO_HOME}/config.yaml"
        fi
        log_ok "Configuration created at ${OTTO_HOME}/config.yaml"
    else
        log_info "Configuration already exists at ${OTTO_HOME}/config.yaml"
    fi

    # Create .env if not exists
    if [ ! -f "${OTTO_HOME}/.env" ]; then
        cp "${OTTO_DIR}/.env.example" "${OTTO_HOME}/.env"
        log_ok "Environment template created at ${OTTO_HOME}/.env"
        log_warn "Edit ${OTTO_HOME}/.env to add your API tokens"
    fi
}

setup_cli_symlink() {
    echo -e "\n${BOLD}Setting up CLI...${NC}\n"

    local target="${HOME}/.local/bin/otto"

    mkdir -p "${HOME}/.local/bin"

    if [ -L "${target}" ] || [ -f "${target}" ]; then
        log_info "CLI symlink already exists at ${target}"
    else
        ln -s "${OTTO_DIR}/otto" "${target}"
        log_ok "CLI symlink created: ${target} -> ${OTTO_DIR}/otto"
    fi

    # Check if ~/.local/bin is in PATH
    if [[ ":${PATH}:" != *":${HOME}/.local/bin:"* ]]; then
        log_warn "${HOME}/.local/bin is not in your PATH"
        log_warn "Add this to your shell profile: export PATH=\"\${HOME}/.local/bin:\${PATH}\""
    fi
}

print_summary() {
    echo -e "\n${BOLD}${GREEN}OTTO setup complete!${NC}\n"
    echo -e "  Config:  ${OTTO_HOME}/config.yaml"
    echo -e "  Secrets: ${OTTO_HOME}/.env"
    echo -e "  State:   ${OTTO_HOME}/state/"
    echo -e "  Agents:  ${OTTO_HOME}/agents/ (custom agents)"
    echo ""
    echo -e "${BOLD}Next steps:${NC}"
    echo "  1. Edit ${OTTO_HOME}/.env with your API tokens"
    echo "  2. Customize ${OTTO_HOME}/config.yaml as needed"
    echo "  3. Run: otto help"
    echo ""
}

main() {
    print_banner
    check_prerequisites
    detect_tools
    setup_config_dir
    setup_cli_symlink
    print_summary
}

main "$@"
