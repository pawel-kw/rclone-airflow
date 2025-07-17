# Makefile for rclone-airflow development

.PHONY: help setup dev-setup test lint format type-check clean docker-build docker-run install pre-commit

# Default target
help:
	@echo "Available targets:"
	@echo "  setup        - Set up development environment"
	@echo "  dev-setup    - Alias for setup"
	@echo "  install      - Install dependencies"
	@echo "  test         - Run tests"
	@echo "  lint         - Run linting (flake8)"
	@echo "  format       - Format code (black)"
	@echo "  type-check   - Run type checking (mypy)"
	@echo "  pre-commit   - Run pre-commit hooks"
	@echo "  docker-build - Build Docker image"
	@echo "  docker-run   - Run with Docker Compose"
	@echo "  clean        - Clean up generated files"
	@echo "  all-checks   - Run all code quality checks"

# Set up development environment
setup: dev-setup

dev-setup:
	@echo "Setting up development environment..."
	./scripts/setup-dev.sh

# Install dependencies
install:
	@echo "Installing dependencies..."
	pip install -r requirements.txt
	pip install -r requirements-dev.txt

# Run tests
test:
	@echo "Running tests..."
	python -m pytest tests/ -v --cov=dags --cov-report=term-missing

# Run linting
lint:
	@echo "Running flake8..."
	flake8 dags/ tests/ scripts/

# Format code
format:
	@echo "Formatting code with black..."
	black dags/ tests/ scripts/
	@echo "Sorting imports with isort..."
	isort dags/ tests/ scripts/

# Type checking
type-check:
	@echo "Running mypy type checking..."
	mypy dags/ --ignore-missing-imports

# Run pre-commit hooks
pre-commit:
	@echo "Running pre-commit hooks..."
	pre-commit run --all-files

# Run all code quality checks
all-checks: lint type-check test
	@echo "All checks completed!"

# Docker operations
docker-build:
	@echo "Building Docker image..."
	docker build -t rclone-airflow:dev .

docker-run:
	@echo "Running with Docker Compose..."
	docker-compose -f docker-compose.portainer.yml up -d

# Clean up
clean:
	@echo "Cleaning up..."
	find . -type f -name "*.pyc" -delete
	find . -type d -name "__pycache__" -delete
	find . -type d -name "*.egg-info" -exec rm -rf {} +
	find . -type f -name ".coverage" -delete
	rm -rf .pytest_cache/
	rm -rf .mypy_cache/

# Development workflow targets
dev-check: format lint type-check test
	@echo "Development checks completed!"

dev-install: setup install
	@echo "Development environment ready!"

# Quick test target for continuous development
quick-test:
	@echo "Running quick tests..."
	python -m pytest tests/ -x --tb=short

# Documentation (if needed)
docs:
	@echo "Building documentation..."
	@echo "Documentation generation not yet implemented"

# Environment management
env-create:
	@echo "Creating .env file from example..."
	cp .env.example .env
	@echo "Please edit .env file with your configuration"

env-check:
	@echo "Checking environment configuration..."
	@if [ ! -f .env ]; then echo "❌ .env file not found"; else echo "✅ .env file found"; fi
	@if [ ! -d venv ]; then echo "❌ Virtual environment not found"; else echo "✅ Virtual environment found"; fi
