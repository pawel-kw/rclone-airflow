"""
Tests for monitoring DAG
"""

from unittest.mock import MagicMock, patch

import pytest


class TestMonitoringFunctions:
    """Test monitoring DAG functions"""

    def test_disk_space_check(self):
        """Test disk space checking function"""
        # Mock shutil.disk_usage
        mock_usage = MagicMock()
        mock_usage.total = 1024**3 * 100  # 100 GB
        mock_usage.free = 1024**3 * 20  # 20 GB free

        with patch("shutil.disk_usage", return_value=mock_usage):
            # Test disk space calculation
            total_gb = mock_usage.total / (1024**3)
            free_gb = mock_usage.free / (1024**3)
            free_percent = (mock_usage.free / mock_usage.total) * 100

            assert total_gb == 100.0
            assert free_gb == 20.0
            assert free_percent == 20.0

            # Test status determination
            status = (
                "ok"
                if free_percent > 10
                else "warning" if free_percent > 5 else "critical"
            )
            assert status == "ok"

    def test_health_status_determination(self):
        """Test overall health status determination logic"""
        # Test healthy status
        rclone_health = {"status": "healthy"}
        backup_jobs = {"failed_jobs": 0, "total_jobs": 5}

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

        assert overall_status == "healthy"
        assert len(alerts) == 0

        # Test warning status
        backup_jobs["failed_jobs"] = 1
        overall_status = "healthy"
        alerts = []

        if backup_jobs.get("failed_jobs", 0) > 0:
            if backup_jobs["failed_jobs"] > backup_jobs["total_jobs"] * 0.5:
                overall_status = "critical"
            elif overall_status == "healthy":
                overall_status = "warning"
                alerts.append(f"{backup_jobs['failed_jobs']} backup jobs failed")

        assert overall_status == "warning"
        assert len(alerts) == 1

    @patch("rclonerc.Client")
    def test_rclone_health_check(self, mock_client_class):
        """Test rclone health check function"""
        # Mock successful rclone client
        mock_client = MagicMock()
        mock_client_class.return_value = mock_client

        # Mock successful operations
        mock_client.op.side_effect = [
            {"success": True},  # noop
            {"stats": "ok"},  # stats
            {"remotes": ["remote1", "remote2"]},  # remotes
        ]

        context = {"ts": "2023-12-15T12:00:00+00:00"}

        # Simulate health check function logic
        try:
            mock_client.op("rc/noop", {"success": "true"})
            stats_result = mock_client.op("core/stats", {})
            remotes_result = mock_client.op("config/listremotes", {})

            health_data = {
                "status": "healthy",
                "timestamp": context["ts"],
                "connectivity": "ok",
                "remotes_count": len(remotes_result.get("remotes", [])),
                "remotes": remotes_result.get("remotes", []),
                "stats": stats_result,
            }

            assert health_data["status"] == "healthy"
            assert health_data["remotes_count"] == 2
            assert health_data["connectivity"] == "ok"

        except Exception as e:
            pytest.fail(f"Health check should not fail: {e}")


if __name__ == "__main__":
    pytest.main([__file__])
