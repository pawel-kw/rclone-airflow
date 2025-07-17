#!/usr/bin/env python3
"""
Simple script to test rclone connection
This can be used for development and debugging
"""

import os
import sys
from pathlib import Path

# Add project root to Python path
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root))

try:
    import rclonerc

    print("✅ rclonerc module imported successfully")
except ImportError as e:
    print(f"❌ Failed to import rclonerc: {e}")
    print("Make sure rclonerc is installed: pip install rclonerc")
    sys.exit(1)


def test_rclone_connection():
    """Test basic rclone connection"""
    try:
        # Create rclone client
        client = rclonerc.Client(
            group="test",
            timeout=10,
        )
        print("✅ Rclone client created successfully")

        # Test basic connectivity
        result = client.op("rc/noop", {"success": "true"})
        print(f"✅ Rclone connectivity test passed: {result}")

        # List remotes
        remotes = client.op("config/listremotes", {})
        remote_list = remotes.get("remotes", [])
        print(f"✅ Found {len(remote_list)} configured remotes: {remote_list}")

        # Get server stats
        stats = client.op("core/stats", {})
        print(f"✅ Server stats retrieved: {stats}")

        return True

    except Exception as e:
        print(f"❌ Rclone connection test failed: {e}")
        print("\nTroubleshooting tips:")
        print("1. Make sure rclone server is running")
        print("2. Check RCLONERC_* environment variables")
        print("3. Verify rclone configuration")
        return False


def main():
    """Main function"""
    print("🧪 Testing rclone connection...")
    print(f"Project root: {project_root}")

    # Show environment variables
    rclone_vars = {k: v for k, v in os.environ.items() if k.startswith("RCLONE")}
    if rclone_vars:
        print(f"Rclone environment variables: {rclone_vars}")
    else:
        print("⚠️  No RCLONE* environment variables found")

    # Test connection
    success = test_rclone_connection()

    if success:
        print("\n✅ All tests passed!")
        return 0
    else:
        print("\n❌ Tests failed!")
        return 1


if __name__ == "__main__":
    sys.exit(main())
