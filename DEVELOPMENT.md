# Development Guide

This guide covers how to set up and work with the rclone-airflow project in a development environment.

## 🚀 Quick Development Setup

### 1. Set Up Virtual Environment

The easiest way to get started:

```bash
# Run the development setup script
./manage.sh dev-setup
```

Or manually:

```bash
# Create virtual environment
python3 -m venv venv

# Activate virtual environment
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
pip install -r requirements-dev.txt

# Install pre-commit hooks
pre-commit install
```

### 2. Activate Virtual Environment

```bash
# Activate the virtual environment
source venv/bin/activate

# Verify installation
python --version
pip list | grep -E "(airflow|rclonerc)"
```

### 3. Configure Environment

```bash
# Create .env file from example
cp .env.example .env

# Edit configuration
nano .env  # or your preferred editor
```

## 📁 Project Structure

```
rclone-airflow/
├── dags/                    # Airflow DAG files
│   ├── backup_jobs.py       # Dynamic backup job DAGs
│   ├── monitoring.py        # System monitoring DAG
│   └── rclone.py           # Basic rclone test DAG
├── tests/                   # Test files
│   ├── test_backup_jobs.py  # Backup job tests
│   └── test_monitoring.py   # Monitoring tests
├── scripts/                 # Utility scripts
│   ├── setup-dev.sh        # Development setup
│   └── test-rclone.py      # Rclone connection test
├── conf/                    # Configuration files
│   ├── jobs.yml            # Backup job definitions
│   └── rclone/             # Rclone configuration
├── .vscode/                 # VS Code configuration
├── requirements.txt         # Production dependencies
├── requirements-dev.txt     # Development dependencies
├── Makefile                # Development tasks
└── manage.sh               # Management script
```

## 🛠️ Development Workflow

### Using the Management Script

```bash
# Set up development environment
./manage.sh dev-setup

# Run tests
./manage.sh test

# Lint code
./manage.sh lint

# Format code
./manage.sh format

# Test rclone connection
./manage.sh test-rclone
```

### Using Make Commands

```bash
# Set up development environment
make dev-setup

# Run all checks
make all-checks

# Format code
make format

# Run tests
make test

# Type checking
make type-check

# Clean up generated files
make clean
```

### Manual Commands

```bash
# Activate virtual environment
source venv/bin/activate

# Run tests with coverage
python -m pytest tests/ -v --cov=dags --cov-report=term-missing

# Format code
black dags/ tests/ scripts/
isort dags/ tests/ scripts/

# Lint code
flake8 dags/ tests/ scripts/

# Type checking
mypy dags/ --ignore-missing-imports

# Run pre-commit hooks
pre-commit run --all-files
```

## 🧪 Testing

### Running Tests

```bash
# Run all tests
pytest tests/

# Run with coverage
pytest tests/ --cov=dags --cov-report=html

# Run specific test file
pytest tests/test_backup_jobs.py -v

# Run quick tests (stop on first failure)
pytest tests/ -x --tb=short
```

### Test Structure

- `tests/test_backup_jobs.py` - Tests for backup job logic
- `tests/test_monitoring.py` - Tests for monitoring functionality

### Writing Tests

Tests use pytest and follow these patterns:

```python
def test_function_name():
    """Test description"""
    # Arrange
    input_data = {...}

    # Act
    result = function_to_test(input_data)

    # Assert
    assert result == expected_value
```

## 🔧 Development Tools

### Code Formatting

- **Black**: Automatic code formatting
- **isort**: Import sorting
- **Configuration**: See `pyproject.toml`

```bash
# Format all code
black .
isort .

# Check what would be formatted
black --check .
```

### Linting

- **flake8**: PEP 8 compliance and error checking
- **Configuration**: See `.flake8`

```bash
# Lint all code
flake8 dags/ tests/ scripts/

# Lint specific file
flake8 dags/backup_jobs.py
```

### Type Checking

- **mypy**: Static type checking
- **Configuration**: See `pyproject.toml`

```bash
# Type check DAGs
mypy dags/ --ignore-missing-imports
```

### Pre-commit Hooks

Automatic code quality checks before commits:

```bash
# Install hooks
pre-commit install

# Run hooks manually
pre-commit run --all-files

# Skip hooks for a commit (not recommended)
git commit --no-verify -m "message"
```

## 🐳 Development with Docker

### Local Development Container

```bash
# Build development image
docker build -t rclone-airflow:dev .

# Run with development overrides
docker-compose -f docker-compose.portainer.yml up -d

# Access running container
docker exec -it <container_name> bash
```

### Testing Against Real Airflow

```bash
# Start full stack for testing
./manage.sh deploy

# View logs
./manage.sh logs airflow-scheduler

# Stop stack
./manage.sh stop
```

## 🎯 VS Code Integration

The project includes VS Code configuration for:

### Settings (`.vscode/settings.json`)
- Python interpreter path pointing to virtual environment
- Automatic formatting on save
- Linting configuration
- Test discovery

### Debug Configuration (`.vscode/launch.json`)
- Debug DAG files
- Run tests with debugger
- Test rclone connection

### Recommended Extensions
- Python
- Python Debugger
- YAML
- Docker
- GitLens

## 📝 Adding New Features

### Adding a New DAG

1. Create DAG file in `dags/` directory
2. Follow existing patterns for imports and structure
3. Add tests in `tests/`
4. Update documentation

### Adding New Backup Job Features

1. Modify `dags/backup_jobs.py`
2. Update job schema in `conf/jobs.yml` example
3. Add tests for new functionality
4. Update documentation

### Adding New Monitoring

1. Add functions to `dags/monitoring.py`
2. Create new tasks in the monitoring DAG
3. Add tests for monitoring logic
4. Update alerting if needed

## 🚨 Troubleshooting

### Virtual Environment Issues

```bash
# Remove and recreate virtual environment
rm -rf venv
./manage.sh dev-setup
```

### Import Errors

```bash
# Check Python path
echo $PYTHONPATH

# Activate virtual environment
source venv/bin/activate

# Verify package installation
pip list | grep -E "(airflow|rclonerc)"
```

### Airflow Import Errors

The DAG files import Airflow modules, which may show as errors in development:

- These are expected when not running in an Airflow environment
- Tests use mocking to avoid real Airflow dependencies
- For full testing, use the Docker environment

### Test Failures

```bash
# Run tests with more verbose output
pytest tests/ -v -s

# Run specific failing test
pytest tests/test_backup_jobs.py::test_function_name -v

# Check test coverage
pytest tests/ --cov=dags --cov-report=html
open htmlcov/index.html
```

### Rclone Connection Issues

```bash
# Test rclone connection
./manage.sh test-rclone

# Or run test script directly
python scripts/test-rclone.py

# Check environment variables
env | grep RCLONE
```

## 📚 Additional Resources

- [Airflow Development Documentation](https://airflow.apache.org/docs/apache-airflow/stable/start.html)
- [Rclone Documentation](https://rclone.org/docs/)
- [pytest Documentation](https://docs.pytest.org/)
- [Black Documentation](https://black.readthedocs.io/)
- [Pre-commit Documentation](https://pre-commit.com/)
