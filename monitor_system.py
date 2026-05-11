#!/usr/bin/env python3
"""
Monitoring script for Tally DQM/TTCM system
Run periodically to check system health and send alerts if needed
"""

import sys
import os
import subprocess
from datetime import datetime, timedelta
import json

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
            # Parse the second line (actual filesystem info)
            parts = lines[1].split()
            if len(parts) >= 5:
                use_percent = int(parts[4].rstrip('%'))
                return use_percent < 90  # Alert if >90% used

        return True
    except Exception as e:
        print(f"Error checking disk space: {e}")
        return False

def check_bigquery_access():
    """Quick BigQuery connectivity test"""
    try:
        from google.cloud import bigquery

        client = bigquery.Client(project='datarecsv2')
        # Simple query to test connectivity
        query = "SELECT 1 as test"
        client.query(query).result()
        return True

    except Exception as e:
        print(f"BigQuery access failed: {e}")
        return False

def check_airflow_dags():
    """Check if Airflow DAGs are loaded and not paused"""
    try:
        from airflow.models import DagBag
        from airflow import settings
        from airflow.utils.state import DagRunState

        dagbag = DagBag(dag_folder='/opt/tally/airflow/dags', include_examples=False)

        expected_dags = ['dqm_monthly_execution', 'ttcm_monthly_execution']
        issues = []

        for dag_id in expected_dags:
            if dag_id not in dagbag.dags:
                issues.append(f"DAG {dag_id} not loaded")
            else:
                dag = dagbag.dags[dag_id]
                if dag.is_paused:
                    issues.append(f"DAG {dag_id} is paused")

        return len(issues) == 0, issues

    except Exception as e:
        print(f"Error checking Airflow DAGs: {e}")
        return False, [str(e)]

def get_recent_dag_runs():
    """Get status of recent DAG runs"""
    try:
        from airflow.models import DagRun
        from airflow import settings

        session = settings.Session()

        # Check last 7 days
        since = datetime.now() - timedelta(days=7)

        dag_runs = session.query(DagRun).filter(
            DagRun.execution_date >= since,
            DagRun.dag_id.in_(['dqm_monthly_execution', 'ttcm_monthly_execution'])
        ).all()

        results = {}
        for run in dag_runs:
            dag_id = run.dag_id
            if dag_id not in results:
                results[dag_id] = []

            results[dag_id].append({
                'execution_date': run.execution_date.isoformat(),
                'state': run.state.value if hasattr(run.state, 'value') else str(run.state),
                'start_date': run.start_date.isoformat() if run.start_date else None,
                'end_date': run.end_date.isoformat() if run.end_date else None
            })

        session.close()
        return results

    except Exception as e:
        print(f"Error getting DAG runs: {e}")
        return {}

def send_alert(subject, message):
    """Send alert email (placeholder - integrate with your email system)"""
    print(f"🚨 ALERT: {subject}")
    print(message)
    print("-" * 50)

    # TODO: Integrate with HSBC email system
    # Example: send_email(to='team@hsbc.com', subject=subject, body=message)

def main():
    """Run health checks"""
    print(f"🔍 Tally System Health Check - {datetime.now()}")
    print("=" * 60)

    checks = [
        ("Airflow Webserver", lambda: check_service_status('airflow-webserver')),
        ("Airflow Scheduler", lambda: check_service_status('airflow-scheduler')),
        ("Tally Web Server", lambda: check_service_status('tally-server')),
        ("Disk Space", check_disk_space),
        ("BigQuery Access", check_bigquery_access),
    ]

    alerts = []
    all_healthy = True

    for check_name, check_func in checks:
        try:
            result = check_func()
            status = "✅ OK" if result else "❌ FAIL"
            print(f"  {check_name}: {status}")

            if not result:
                all_healthy = False
                alerts.append(f"{check_name} check failed")

        except Exception as e:
            print(f"  {check_name}: ❌ ERROR - {e}")
            all_healthy = False
            alerts.append(f"{check_name} error: {e}")

    # Check Airflow DAGs
    dags_healthy, dag_issues = check_airflow_dags()
    if dags_healthy:
        print("  Airflow DAGs: ✅ OK")
    else:
        print("  Airflow DAGs: ❌ FAIL")
        print(f"    Issues: {', '.join(dag_issues)}")
        all_healthy = False
        alerts.extend(dag_issues)

    # Show recent DAG runs
    print("\n📊 Recent DAG Runs (Last 7 days):")
    dag_runs = get_recent_dag_runs()
    if dag_runs:
        for dag_id, runs in dag_runs.items():
            print(f"  {dag_id}:")
            for run in runs[-3:]:  # Show last 3 runs
                print(f"    {run['execution_date'][:10]}: {run['state']}")
    else:
        print("  No recent DAG runs found")

    print("\n" + "=" * 60)

    if all_healthy:
        print("🎉 All systems healthy!")
    else:
        alert_message = "\n".join(alerts)
        send_alert(
            "Tally System Health Alert",
            f"The following issues were detected:\n\n{alert_message}\n\nPlease check the system logs and resolve issues."
        )

    return 0 if all_healthy else 1

if __name__ == "__main__":
    # Ensure we're in the right environment
    if 'AIRFLOW_HOME' not in os.environ:
        os.environ['AIRFLOW_HOME'] = '/opt/tally/airflow'

    sys.exit(main())