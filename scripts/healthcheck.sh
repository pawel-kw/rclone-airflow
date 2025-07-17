#!/bin/bash

# Health check script for rclone-airflow containers
# This script can be used to check the health of various services

SERVICE_TYPE=${1:-"airflow"}

case "$SERVICE_TYPE" in
    "airflow-webserver")
        curl -f http://localhost:8080/health || exit 1
        ;;
    "airflow-scheduler")
        airflow jobs check --job-type SchedulerJob --hostname "${HOSTNAME}" || exit 1
        ;;
    "airflow-worker")
        celery --app airflow.executors.celery_executor.app inspect ping -d "celery@${HOSTNAME}" || exit 1
        ;;
    "rclone")
        wget --no-verbose --tries=1 --spider \
        "http://${RCLONERC_USERNAME}:${RCLONERC_PASSWORD}@localhost:5572/metrics" || exit 1
        ;;
    "postgres")
        pg_isready -U airflow || exit 1
        ;;
    "redis")
        redis-cli ping || exit 1
        ;;
    *)
        echo "Unknown service type: $SERVICE_TYPE"
        exit 1
        ;;
esac

exit 0
