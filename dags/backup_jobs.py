"""
Dynamic Rclone Backup DAGs Generator

This module creates Airflow DAGs dynamically based on backup job configurations
defined in jobs.yml. Each job becomes a separate DAG with its own schedule.
"""

import logging
import os
from datetime import timedelta
from typing import Any, Dict

import rclonerc
import yaml
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.utils.dates import days_ago

logger = logging.getLogger(__name__)

# Configuration
JOBS_CONFIG_PATH = os.getenv("BACKUP_JOBS_CONF", "/opt/backup_config/jobs.yml")
DEFAULT_RETRIES = 3
DEFAULT_RETRY_DELAY = timedelta(minutes=5)


def get_rclone_client():
    """Get configured rclone client"""
    return rclonerc.Client(
        group="airflow-backup",
        timeout=3600,  # 1 hour timeout for large transfers
    )


def test_rclone_connection():
    """Test rclone connection"""
    try:
        client = get_rclone_client()
        result = client.op("rc/noop", {"success": "true"})
        logger.info("Rclone connection test successful: %s", result)
        return result
    except Exception as e:
        logger.error("Rclone connection test failed: %s", e)
        raise


def run_backup_job(job_name: str, job_config: Dict[str, Any], **context):
    """
    Execute a backup job using rclone

    Args:
        job_name: Name of the backup job
        job_config: Job configuration dictionary
        context: Airflow context
    """
    client = get_rclone_client()

    source = job_config["source"]
    target = job_config["target"]
    backup_dir = job_config.get("backup")

    logger.info(f"Starting backup job '{job_name}'")
    logger.info(f"Source: {source}")
    logger.info(f"Target: {target}")

    try:
        # Prepare rclone command parameters
        if backup_dir:
            # Use backup-dir for versioned backups
            backup_timestamp = context["ts_nodash"]
            full_backup_dir = f"{backup_dir}/{backup_timestamp}"

            params = {
                "srcFs": source,
                "dstFs": target,
                "opt": {
                    "backup-dir": full_backup_dir,
                    "verbose": True,
                    "stats-log-level": "INFO",
                    "stats": "30s",
                },
            }

            # Use sync for backup-dir operations
            operation = "sync/sync"
            logger.info(f"Using backup directory: {full_backup_dir}")

        else:
            # Simple copy without backup-dir
            params = {
                "srcFs": source,
                "dstFs": target,
                "opt": {"verbose": True, "stats-log-level": "INFO", "stats": "30s"},
            }

            # Use copy for simple operations
            operation = "sync/copy"

        # Add any additional rclone options from job config
        rclone_opts = job_config.get("rclone_options", {})
        params["opt"].update(rclone_opts)

        logger.info(f"Executing rclone {operation} with params: {params}")

        # Execute the rclone operation
        result = client.op(operation, params)

        # Log the results
        logger.info(f"Backup job '{job_name}' completed successfully")
        logger.info(f"Result: {result}")

        # Store results in XCom for monitoring
        return {
            "job_name": job_name,
            "status": "success",
            "source": source,
            "target": target,
            "backup_dir": backup_dir,
            "result": result,
            "timestamp": context["ts"],
        }

    except Exception as e:
        logger.error(f"Backup job '{job_name}' failed: {str(e)}")
        # Log error information for debugging
        logger.error(
            f"Failed job details - source: {source}, target: {target}, "
            f"backup_dir: {backup_dir}, timestamp: {context['ts']}"
        )
        raise Exception(f"Backup job failed: {str(e)}") from e


def load_backup_jobs():
    """Load backup job configurations from YAML file"""
    try:
        if not os.path.exists(JOBS_CONFIG_PATH):
            logger.warning(f"Jobs config file not found: {JOBS_CONFIG_PATH}")
            return {}

        with open(JOBS_CONFIG_PATH, "r") as f:
            jobs = yaml.safe_load(f) or {}

        logger.info(f"Loaded {len(jobs)} backup jobs from {JOBS_CONFIG_PATH}")
        return jobs

    except Exception as e:
        logger.error(f"Failed to load jobs config: {e}")
        return {}


def create_backup_dag(job_name: str, job_config: Dict[str, Any]) -> DAG:
    """
    Create a DAG for a backup job

    Args:
        job_name: Name of the backup job
        job_config: Job configuration

    Returns:
        Configured DAG instance
    """

    # Validate required fields
    required_fields = ["cron", "source", "target"]
    for field in required_fields:
        if field not in job_config:
            raise ValueError(f"Missing required field '{field}' in job '{job_name}'")

    # DAG configuration
    dag_id = f"backup_{job_name}"

    default_args = {
        "owner": "rclone-airflow",
        "depends_on_past": False,
        "start_date": days_ago(1),
        "email_on_failure": job_config.get("email_on_failure", False),
        "email_on_retry": False,
        "retries": job_config.get("retries", DEFAULT_RETRIES),
        "retry_delay": timedelta(minutes=job_config.get("retry_delay_minutes", 5)),
        "max_active_runs": 1,  # Prevent overlapping runs
    }

    # Create the DAG
    dag = DAG(
        dag_id=dag_id,
        default_args=default_args,
        description=f"Backup job: {job_name}",
        schedule_interval=job_config["cron"],
        catchup=job_config.get("catchup", False),
        tags=["backup", "rclone", job_name],
        is_paused_upon_creation=job_config.get("paused", True),
    )

    # Connection test task
    test_task = PythonOperator(
        task_id="test_connection",
        python_callable=test_rclone_connection,
        dag=dag,
    )

    # Backup task
    backup_task = PythonOperator(
        task_id="run_backup",
        python_callable=run_backup_job,
        op_kwargs={"job_name": job_name, "job_config": job_config},
        dag=dag,
    )

    # Set task dependencies
    test_task >> backup_task

    return dag


# Load backup jobs and create DAGs
backup_jobs = load_backup_jobs()

# Create a connection test DAG
test_dag = DAG(
    dag_id="rclone_connection_test",
    default_args={
        "owner": "rclone-airflow",
        "depends_on_past": False,
        "start_date": days_ago(1),
        "retries": 1,
    },
    description="Test rclone connection",
    schedule_interval=None,  # Manual trigger only
    catchup=False,
    tags=["rclone", "test"],
    is_paused_upon_creation=False,
)

test_connection_task = PythonOperator(
    task_id="test_connection",
    python_callable=test_rclone_connection,
    dag=test_dag,
)

# Create DAGs for each backup job
for job_name, job_config in backup_jobs.items():
    try:
        dag = create_backup_dag(job_name, job_config)
        # Add DAG to globals so Airflow can find it
        globals()[dag.dag_id] = dag
        logger.info(f"Created DAG for backup job: {job_name}")
    except Exception as e:
        logger.error(f"Failed to create DAG for job '{job_name}': {e}")

logger.info(f"Successfully created {len(backup_jobs)} backup DAGs")
