#!/usr/bin/env python3
"""
Monitoring script for Tally DQM/TTCM system
Run periodically to check system health
"""

import sys
import subprocess
from datetime import datetime


def check_service_status(service_name):
    """Check if a systemd service is running"""
    try:
        result = subprocess.run(
            ['systemctl', 'is-active', service_name],
            capture_output=True,
            text=True,
            timeout=10
        )
        return result.stdout.strip() == 'active'
    except Exception as e:
        print(f"Error checking {service_name}: {e}")
        return False


def check_disk_space():
    """Check available disk space"""
    try:
        result = subprocess.run(
            ['df', '/opt/tally'],
            capture_output=True,
            text=True,
            timeout=10
        )

        lines = result.stdout.strip().split('\n')
        if len(lines) >= 2:
            parts = lines[1].split()
            if len(parts) >= 5:
                use_percent = int(parts[4].rstrip('%'))
                return use_percent < 90

        return True
    except Exception as e:
        print(f"Error checking disk space: {e}")
        return False


def check_bigquery_access():
    """Quick BigQuery connectivity test"""
    try:
        from google.cloud import bigquery

        client = bigquery.Client()
        query = "SELECT 1 as test"
        client.query(query).result()
        return True

    except Exception as e:
        print(f"BigQuery access failed: {e}")
        return False


def main():
    """Run health checks"""
    print(f"🔍 Tally System Health Check - {datetime.now()}")
    print("=" * 60)

    checks = [
        ("Tally Web Server", lambda: check_service_status('tally-server')),
        ("Disk Space", check_disk_space),
        ("BigQuery Access", check_bigquery_access),
    ]

    all_healthy = True

    for check_name, check_func in checks:
        try:
            result = check_func()
            status = "✅ OK" if result else "❌ FAIL"
            print(f"  {check_name}: {status}")

            if not result:
                all_healthy = False

        except Exception as e:
            print(f"  {check_name}: ❌ ERROR - {e}")
            all_healthy = False

    print("\n" + "=" * 60)

    if all_healthy:
        print("🎉 All systems healthy!")
    else:
        print("❌ One or more checks failed. Please check the system logs.")

    return 0 if all_healthy else 1


if __name__ == "__main__":
    sys.exit(main())
