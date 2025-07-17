"""
Backup System Monitoring DAG

This DAG provides monitoring and alerting capabilities for the backup system.
It checks the health of rclone, monitors recent backup job status, and can send alerts.
"""

import logging
from datetime import datetime, timedelta

import rclonerc
from airflow import DAG
from airflow.models import DagRun
from airflow.operators.python import PythonOperator
from airflow.utils.dates import days_ago
from airflow.utils.state import State

logger = logging.getLogger(__name__)


def get_rclone_client():
    """Get configured rclone client"""
    return rclonerc.Client(
        group="monitoring",
        timeout=30,
    )


def check_rclone_health(**context):
    """
    Check rclone server health and connectivity

    Returns:
        dict: Health check results
    """
    try:
        client = get_rclone_client()

        # Basic connectivity test
        client.op("rc/noop", {"success": "true"})

        # Get server stats
        stats_result = client.op("core/stats", {})

        # List configured remotes
        remotes_result = client.op("config/listremotes", {})

        health_data = {
            "status": "healthy",
            "timestamp": context["ts"],
            "connectivity": "ok",
            "remotes_count": len(remotes_result.get("remotes", [])),
            "remotes": remotes_result.get("remotes", []),
            "stats": stats_result,
        }

        logger.info(f"Rclone health check passed: {health_data}")
        return health_data

    except Exception as e:
        error_data = {
            "status": "unhealthy",
            "timestamp": context["ts"],
            "error": str(e),
            "connectivity": "failed",
        }
        logger.error(f"Rclone health check failed: {error_data}")
        return error_data


def check_recent_backup_jobs(**context):
    """
    Check status of recent backup jobs

    Returns:
        dict: Summary of recent backup job statuses
    """
    from sqlalchemy import and_

    # Get recent DAG runs for backup jobs
    since_date = datetime.now() - timedelta(hours=24)

    session = context["session"]

    # Query recent backup DAG runs
    backup_dags = (
        session.query(DagRun)
        .filter(
            and_(DagRun.dag_id.like("backup_%"), DagRun.execution_date >= since_date)
        )
        .all()
    )

    job_summary = {
        "check_timestamp": context["ts"],
        "period_hours": 24,
        "total_jobs": len(backup_dags),
        "successful_jobs": 0,
        "failed_jobs": 0,
        "running_jobs": 0,
        "job_details": [],
    }

    for dag_run in backup_dags:
        status = dag_run.state

        if status == State.SUCCESS:
            job_summary["successful_jobs"] += 1
        elif status == State.FAILED:
            job_summary["failed_jobs"] += 1
        elif status == State.RUNNING:
            job_summary["running_jobs"] += 1

        job_detail = {
            "dag_id": dag_run.dag_id,
            "execution_date": dag_run.execution_date.isoformat(),
            "state": status,
            "start_date": (
                dag_run.start_date.isoformat() if dag_run.start_date else None
            ),
            "end_date": dag_run.end_date.isoformat() if dag_run.end_date else None,
        }

        job_summary["job_details"].append(job_detail)

    logger.info(f"Backup jobs summary: {job_summary}")
    return job_summary


def check_disk_space(**context):
    """
    Check available disk space for backup operations

    Returns:
        dict: Disk space information
    """
    import shutil

    paths_to_check = ["/opt/airflow/logs", "/tmp", "/"]

    disk_info = {"check_timestamp": context["ts"], "paths": {}}

    for path in paths_to_check:
        try:
            usage = shutil.disk_usage(path)
            total_gb = usage.total / (1024**3)
            free_gb = usage.free / (1024**3)
            used_gb = (usage.total - usage.free) / (1024**3)
            free_percent = (usage.free / usage.total) * 100

            disk_info["paths"][path] = {
                "total_gb": round(total_gb, 2),
                "used_gb": round(used_gb, 2),
                "free_gb": round(free_gb, 2),
                "free_percent": round(free_percent, 2),
                "status": (
                    "ok"
                    if free_percent > 10
                    else "warning" if free_percent > 5 else "critical"
                ),
            }

        except Exception as e:
            disk_info["paths"][path] = {"error": str(e), "status": "error"}

    logger.info(f"Disk space check: {disk_info}")
    return disk_info


def generate_monitoring_report(**context):
    """
    Generate a comprehensive monitoring report

    Returns:
        dict: Complete system monitoring report
    """
    # Get data from previous tasks
    ti = context["ti"]

    rclone_health = ti.xcom_pull(task_ids="check_rclone_health")
    backup_jobs = ti.xcom_pull(task_ids="check_backup_jobs")
    disk_space = ti.xcom_pull(task_ids="check_disk_space")

    # Determine overall system health
    overall_status = "healthy"
    alerts = []

    # Check rclone health
    if rclone_health.get("status") != "healthy":
        overall_status = "warning"
        alerts.append("Rclone connectivity issues detected")

    # Check backup job failures
    if backup_jobs.get("failed_jobs", 0) > 0:
        if backup_jobs["failed_jobs"] > backup_jobs["total_jobs"] * 0.5:
            overall_status = "critical"
        elif overall_status == "healthy":
            overall_status = "warning"
        alerts.append(
            f"{backup_jobs['failed_jobs']} backup jobs failed in the last 24 hours"
        )

    # Check disk space
    for path, info in disk_space.get("paths", {}).items():
        if info.get("status") == "critical":
            overall_status = "critical"
            alerts.append(
                f"Critical disk space on {path}: "
                f"{info.get('free_percent', 0):.1f}% free"
            )
        elif info.get("status") == "warning" and overall_status == "healthy":
            overall_status = "warning"
            alerts.append(
                f"Low disk space on {path}: {info.get('free_percent', 0):.1f}% free"
            )

    report = {
        "timestamp": context["ts"],
        "overall_status": overall_status,
        "alerts": alerts,
        "rclone_health": rclone_health,
        "backup_jobs": backup_jobs,
        "disk_space": disk_space,
        "summary": {
            "total_backup_jobs_24h": backup_jobs.get("total_jobs", 0),
            "successful_backup_jobs_24h": backup_jobs.get("successful_jobs", 0),
            "failed_backup_jobs_24h": backup_jobs.get("failed_jobs", 0),
            "rclone_status": rclone_health.get("status", "unknown"),
            "remotes_configured": rclone_health.get("remotes_count", 0),
        },
    }

    logger.info(f"Monitoring report generated: {report}")
    return report


# DAG definition
default_args = {
    "owner": "rclone-airflow",
    "depends_on_past": False,
    "start_date": days_ago(1),
    "email_on_failure": True,
    "email_on_retry": False,
    "retries": 1,
    "retry_delay": timedelta(minutes=5),
}

monitoring_dag = DAG(
    dag_id="backup_system_monitoring",
    default_args=default_args,
    description="Monitor backup system health and performance",
    schedule_interval="0 */6 * * *",  # Every 6 hours
    catchup=False,
    tags=["monitoring", "backup", "health"],
    is_paused_upon_creation=False,
)

# Define tasks
check_rclone_task = PythonOperator(
    task_id="check_rclone_health",
    python_callable=check_rclone_health,
    dag=monitoring_dag,
)

check_backup_jobs_task = PythonOperator(
    task_id="check_backup_jobs",
    python_callable=check_recent_backup_jobs,
    dag=monitoring_dag,
)

check_disk_space_task = PythonOperator(
    task_id="check_disk_space",
    python_callable=check_disk_space,
    dag=monitoring_dag,
)

generate_report_task = PythonOperator(
    task_id="generate_report",
    python_callable=generate_monitoring_report,
    dag=monitoring_dag,
)

# Set task dependencies
[
    check_rclone_task,
    check_backup_jobs_task,
    check_disk_space_task,
] >> generate_report_task
