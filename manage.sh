#!/bin/bash

# Rclone-Airflow Configuration Helper Script
# This script helps with common configuration tasks

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_NAME="rclone-airflow-backup"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

usage() {
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  setup           - Initial setup and configuration"
    echo "  dev-setup       - Set up development environment"
    echo "  config-rclone   - Configure rclone remotes"
    echo "  edit-jobs       - Edit backup jobs configuration"
    echo "  test-rclone     - Test rclone connection"
    echo "  test            - Run development tests"
    echo "  lint            - Run code linting"
    echo "  format          - Format code"
    echo "  deploy          - Deploy using docker-compose"
    echo "  status          - Show stack status"
    echo "  logs [service]  - Show logs for a service"
    echo "  restart         - Restart the stack"
    echo "  stop            - Stop the stack"
    echo "  cleanup         - Remove stack and volumes"
    echo "  backup-config   - Backup configuration files"
    echo "  restore-config  - Restore configuration files"
    echo ""
    echo "Examples:"
    echo "  $0 setup"
    echo "  $0 dev-setup"
    echo "  $0 test"
    echo "  $0 logs airflow-scheduler"
    echo "  $0 config-rclone"
}

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

setup() {
    log "Setting up Rclone-Airflow backup system..."

    # Check dependencies
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed or not in PATH"
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose is not installed or not in PATH"
        exit 1
    fi

    # Create directories
    mkdir -p "$SCRIPT_DIR/conf/rclone"
    mkdir -p "$SCRIPT_DIR/logs"
    mkdir -p "$SCRIPT_DIR/plugins"

    # Copy example configuration if jobs.yml doesn't exist
    if [[ ! -f "$SCRIPT_DIR/conf/jobs.yml" ]]; then
        log "Creating example jobs configuration..."
        # jobs.yml already exists with examples
    fi

    # Create .env file if it doesn't exist
    if [[ ! -f "$SCRIPT_DIR/.env" ]]; then
        log "Creating .env file from example..."
        cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
        warn "Please edit .env file with your configuration"
    fi

    # Generate Fernet key if not set
    if ! grep -q "AIRFLOW_FERNET_KEY=." "$SCRIPT_DIR/.env"; then
        log "Generating Airflow Fernet key..."
        FERNET_KEY=$(python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())" 2>/dev/null || echo "")
        if [[ -n "$FERNET_KEY" ]]; then
            sed -i.bak "s/AIRFLOW_FERNET_KEY=/AIRFLOW_FERNET_KEY=$FERNET_KEY/" "$SCRIPT_DIR/.env"
            log "Fernet key generated and saved to .env"
        else
            warn "Could not generate Fernet key. Please install cryptography: pip install cryptography"
        fi
    fi

    log "Setup complete! Next steps:"
    echo "1. Edit .env file with your settings"
    echo "2. Run: $0 config-rclone"
    echo "3. Edit backup jobs: $0 edit-jobs"
    echo "4. Deploy: $0 deploy"
    echo ""
    echo "For development:"
    echo "5. Set up dev environment: $0 dev-setup"
}

dev_setup() {
    log "Setting up development environment..."

    if [[ -f "$SCRIPT_DIR/scripts/setup-dev.sh" ]]; then
        "$SCRIPT_DIR/scripts/setup-dev.sh"
    else
        error "Development setup script not found"
        exit 1
    fi
}

run_tests() {
    log "Running tests..."

    if [[ -d "$SCRIPT_DIR/venv" ]]; then
        source "$SCRIPT_DIR/venv/bin/activate"
        python -m pytest tests/ -v
    else
        warn "Virtual environment not found. Run: $0 dev-setup"
        # Try to run tests anyway
        python -m pytest tests/ -v 2>/dev/null || {
            error "Tests failed. Please set up development environment first."
            exit 1
        }
    fi
}

run_lint() {
    log "Running code linting..."

    if [[ -d "$SCRIPT_DIR/venv" ]]; then
        source "$SCRIPT_DIR/venv/bin/activate"
        flake8 dags/ tests/ scripts/ || warn "Linting found issues"
    else
        warn "Virtual environment not found. Run: $0 dev-setup"
    fi
}

format_code() {
    log "Formatting code..."

    if [[ -d "$SCRIPT_DIR/venv" ]]; then
        source "$SCRIPT_DIR/venv/bin/activate"
        black dags/ tests/ scripts/
        isort dags/ tests/ scripts/
    else
        warn "Virtual environment not found. Run: $0 dev-setup"
    fi
}

config_rclone() {
    log "Configuring rclone..."

    if [[ ! -f "$SCRIPT_DIR/conf/rclone/rclone.conf" ]]; then
        log "No rclone config found. Creating new configuration..."
        docker run --rm -it \
            --user $(id -u):$(id -g) \
            --volume "$SCRIPT_DIR/conf/rclone:/config/rclone" \
            rclone/rclone:1.56.2 config
    else
        log "Existing rclone config found. Opening for editing..."
        docker run --rm -it \
            --user $(id -u):$(id -g) \
            --volume "$SCRIPT_DIR/conf/rclone:/config/rclone" \
            rclone/rclone:1.56.2 config
    fi
}

edit_jobs() {
    log "Opening jobs configuration for editing..."

    if command -v code &> /dev/null; then
        code "$SCRIPT_DIR/conf/jobs.yml"
    elif command -v nano &> /dev/null; then
        nano "$SCRIPT_DIR/conf/jobs.yml"
    elif command -v vi &> /dev/null; then
        vi "$SCRIPT_DIR/conf/jobs.yml"
    else
        error "No suitable editor found. Please edit $SCRIPT_DIR/conf/jobs.yml manually"
    fi
}

test_rclone() {
    log "Testing rclone connection..."

    if [[ ! -f "$SCRIPT_DIR/conf/rclone/rclone.conf" ]]; then
        error "No rclone configuration found. Run: $0 config-rclone"
        exit 1
    fi

    docker run --rm \
        --volume "$SCRIPT_DIR/conf/rclone:/config/rclone" \
        rclone/rclone:1.56.2 listremotes
}

deploy() {
    log "Deploying Rclone-Airflow stack..."

    if [[ ! -f "$SCRIPT_DIR/.env" ]]; then
        error "No .env file found. Run: $0 setup"
        exit 1
    fi

    # Use Portainer compose file
    docker-compose -f "$SCRIPT_DIR/docker-compose.portainer.yml" up -d

    log "Stack deployed! Services starting up..."
    log "Airflow Web UI will be available at: http://localhost:8080"
    log "Rclone Web UI will be available at: http://localhost:5572"
    warn "It may take a few minutes for all services to be ready"
}

show_status() {
    log "Showing stack status..."
    docker-compose -f "$SCRIPT_DIR/docker-compose.portainer.yml" ps
}

show_logs() {
    local service=$1
    if [[ -n "$service" ]]; then
        docker-compose -f "$SCRIPT_DIR/docker-compose.portainer.yml" logs -f "$service"
    else
        docker-compose -f "$SCRIPT_DIR/docker-compose.portainer.yml" logs -f
    fi
}

restart_stack() {
    log "Restarting stack..."
    docker-compose -f "$SCRIPT_DIR/docker-compose.portainer.yml" restart
}

stop_stack() {
    log "Stopping stack..."
    docker-compose -f "$SCRIPT_DIR/docker-compose.portainer.yml" down
}

cleanup() {
    warn "This will remove ALL data including databases and configurations!"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Removing stack and volumes..."
        docker-compose -f "$SCRIPT_DIR/docker-compose.portainer.yml" down -v
        log "Cleanup complete"
    else
        log "Cleanup cancelled"
    fi
}

backup_config() {
    local backup_dir="$SCRIPT_DIR/config-backup-$(date +%Y%m%d-%H%M%S)"
    log "Backing up configuration to $backup_dir..."

    mkdir -p "$backup_dir"
    cp -r "$SCRIPT_DIR/conf" "$backup_dir/"
    cp "$SCRIPT_DIR/.env" "$backup_dir/" 2>/dev/null || true
    cp "$SCRIPT_DIR/docker-compose.portainer.yml" "$backup_dir/"

    log "Configuration backed up to: $backup_dir"
}

restore_config() {
    local backup_dir=$1
    if [[ -z "$backup_dir" ]]; then
        error "Please specify backup directory"
        exit 1
    fi

    if [[ ! -d "$backup_dir" ]]; then
        error "Backup directory not found: $backup_dir"
        exit 1
    fi

    warn "This will overwrite current configuration!"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Restoring configuration from $backup_dir..."
        cp -r "$backup_dir/conf" "$SCRIPT_DIR/"
        cp "$backup_dir/.env" "$SCRIPT_DIR/" 2>/dev/null || true
        log "Configuration restored"
    else
        log "Restore cancelled"
    fi
}

# Main command handling
case "$1" in
    setup)
        setup
        ;;
    dev-setup)
        dev_setup
        ;;
    config-rclone)
        config_rclone
        ;;
    edit-jobs)
        edit_jobs
        ;;
    test-rclone)
        test_rclone
        ;;
    test)
        run_tests
        ;;
    lint)
        run_lint
        ;;
    format)
        format_code
        ;;
    deploy)
        deploy
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs "$2"
        ;;
    restart)
        restart_stack
        ;;
    stop)
        stop_stack
        ;;
    cleanup)
        cleanup
        ;;
    backup-config)
        backup_config
        ;;
    restore-config)
        restore_config "$2"
        ;;
    *)
        usage
        exit 1
        ;;
esac
