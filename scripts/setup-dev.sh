#!/bin/bash

# Development Environment Setup Script
# This script sets up a Python virtual environment for development

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VENV_NAME="venv"
PYTHON_VERSION="python3"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -p, --python   Python executable to use (default: python3)"
    echo "  -n, --name     Virtual environment name (default: venv)"
    echo "  --clean        Remove existing virtual environment first"
    echo ""
    echo "Examples:"
    echo "  $0                    # Create venv with python3"
    echo "  $0 -p python3.9      # Create venv with specific Python version"
    echo "  $0 --clean           # Remove existing venv and create new one"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            usage
            exit 0
            ;;
        -p|--python)
            PYTHON_VERSION="$2"
            shift 2
            ;;
        -n|--name)
            VENV_NAME="$2"
            shift 2
            ;;
        --clean)
            CLEAN_VENV=true
            shift
            ;;
        *)
            error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

VENV_PATH="$PROJECT_ROOT/$VENV_NAME"

# Check if Python is available
if ! command -v "$PYTHON_VERSION" &> /dev/null; then
    error "Python executable '$PYTHON_VERSION' not found"
    error "Please install Python or specify a different version with -p"
    exit 1
fi

# Get Python version info
PYTHON_VERSION_INFO=$($PYTHON_VERSION --version 2>&1)
log "Using $PYTHON_VERSION_INFO"

# Clean existing virtual environment if requested
if [[ "$CLEAN_VENV" == "true" ]] && [[ -d "$VENV_PATH" ]]; then
    log "Removing existing virtual environment at $VENV_PATH"
    rm -rf "$VENV_PATH"
fi

# Create virtual environment if it doesn't exist
if [[ ! -d "$VENV_PATH" ]]; then
    log "Creating virtual environment at $VENV_PATH"
    $PYTHON_VERSION -m venv "$VENV_PATH"
else
    log "Virtual environment already exists at $VENV_PATH"
fi

# Activate virtual environment
log "Activating virtual environment"
source "$VENV_PATH/bin/activate"

# Upgrade pip
log "Upgrading pip"
pip install --upgrade pip

# Install production requirements
if [[ -f "$PROJECT_ROOT/requirements.txt" ]]; then
    log "Installing production requirements"
    pip install -r "$PROJECT_ROOT/requirements.txt"
fi

# Install development requirements
if [[ -f "$PROJECT_ROOT/requirements-dev.txt" ]]; then
    log "Installing development requirements"
    pip install -r "$PROJECT_ROOT/requirements-dev.txt"
fi

# Install pre-commit hooks if available
if [[ -f "$PROJECT_ROOT/.pre-commit-config.yaml" ]]; then
    log "Installing pre-commit hooks"
    pre-commit install
fi

# Create .env file if it doesn't exist
if [[ ! -f "$PROJECT_ROOT/.env" ]] && [[ -f "$PROJECT_ROOT/.env.example" ]]; then
    log "Creating .env file from .env.example"
    cp "$PROJECT_ROOT/.env.example" "$PROJECT_ROOT/.env"
    warn "Please edit .env file with your configuration"
fi

# Generate Airflow Fernet key if not set
if [[ -f "$PROJECT_ROOT/.env" ]] && ! grep -q "AIRFLOW_FERNET_KEY=." "$PROJECT_ROOT/.env"; then
    log "Generating Airflow Fernet key"
    FERNET_KEY=$(python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())" 2>/dev/null || echo "")
    if [[ -n "$FERNET_KEY" ]]; then
        sed -i.bak "s/AIRFLOW_FERNET_KEY=/AIRFLOW_FERNET_KEY=$FERNET_KEY/" "$PROJECT_ROOT/.env"
        log "Fernet key generated and saved to .env"
    else
        warn "Could not generate Fernet key"
    fi
fi

log "Development environment setup complete!"
echo ""
echo "To activate the virtual environment, run:"
echo "  source $VENV_NAME/bin/activate"
echo ""
echo "Available development commands:"
echo "  python -m pytest              # Run tests"
echo "  black .                       # Format code"
echo "  flake8 .                      # Lint code"
echo "  mypy dags/                    # Type checking"
echo "  jupyter notebook              # Start Jupyter"
echo ""
echo "To deactivate the virtual environment, run:"
echo "  deactivate"
