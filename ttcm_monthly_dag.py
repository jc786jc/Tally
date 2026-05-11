"""
Airflow DAG for monthly TTCM (Transaction Type Code Mapping) execution
Runs on the 1st of every month at 3 AM UTC (after DQM)
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.email import EmailOperator
from airflow.utils.email import send_email
import logging
import requests
import json

# Default arguments
default_args = {
    'owner': 'tally-team',
    'depends_on_past': False,
    'start_date': datetime(2024, 1, 1),
    'email_on_failure': True,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
    'email': ['your-email@gmail.com'],  # Replace with your email
}

# DAG definition
dag = DAG(
    'ttcm_monthly_execution',
    default_args=default_args,
    description='Monthly TTCM execution on existing test data',
    schedule_interval='0 3 1 * *',  # 1st of every month at 3 AM (after DQM)
    catchup=False,
    tags=['tally', 'ttcm', 'monthly'],
)

def execute_ttcm_process():
    """
    Execute TTCM process on existing test data
    This function will call the TTCM logic (adapt based on your implementation)
    """
    try:
        logging.info("Starting TTCM execution...")

        # TODO: Replace with actual TTCM execution logic
        # This could be:
        # 1. Direct Python function call if TTCM logic is available
        # 2. API call to your server
        # 3. BigQuery stored procedure execution

        # TTCM involves comparing ML15 (SSCRTYPE) and ML16 (SSCRCEP) tables
        logging.info("Comparing ML15 previous vs current...")
        logging.info("Comparing ML16 previous vs current...")
        logging.info("Generating Reports 1-4...")

        # Simulate processing time
        import time
        time.sleep(45)  # Replace with actual processing

        logging.info("TTCM execution completed successfully")
        return {
            "status": "success",
            "message": "TTCM completed",
            "reports": {
                "r1": {"added": 0, "deleted": 0},
                "r2": {"changed": 0},
                "r3": {"added": 0, "deleted": 0},
                "r4": {"changed": 0}
            }
        }

    except Exception as e:
        logging.error(f"TTCM execution failed: {str(e)}")
        raise

def validate_ttcm_results():
    """
    Validate TTCM results and check for significant changes
    """
    try:
        logging.info("Validating TTCM results...")

        # TODO: Add validation logic
        # Check for significant changes in mappings
        # Verify data consistency
        # Alert on major discrepancies

        # Example thresholds for alerting
        thresholds = {
            'max_added_ml15': 50,
            'max_deleted_ml15': 50,
            'max_changed_ml15': 100,
            'max_added_ml16': 75,
            'max_deleted_ml16': 75,
            'max_changed_ml16': 150
        }

        # TODO: Compare actual results against thresholds
        # If exceeded, log warning or raise exception

        logging.info("TTCM results validation completed")
        return True

    except Exception as e:
        logging.error(f"TTCM validation failed: {str(e)}")
        raise

def send_ttcm_alert(context):
    """
    Send alert email for TTCM execution
    """
    task_instance = context['task_instance']
    execution_date = context['execution_date']

    subject = f"TTCM Monthly Execution Alert - {execution_date.strftime('%Y-%m-%d')}"
    body = f"""
    TTCM Monthly Execution Report

    Execution Date: {execution_date.strftime('%Y-%m-%d %H:%M:%S UTC')}
    DAG: ttcm_monthly_execution
    Task: {task_instance.task_id}

    Status: FAILED

    Error Details:
    {context.get('exception', 'Unknown error')}

    Please check the Airflow logs for more details.
    """

    send_email(
        to=['your-email@hsbc.com', 'team-dl@hsbc.com'],  # Replace with actual emails
        subject=subject,
        html_content=body
    )

# Tasks
execute_ttcm = PythonOperator(
    task_id='execute_ttcm',
    python_callable=execute_ttcm_process,
    dag=dag,
    on_failure_callback=send_ttcm_alert,
)

validate_results = PythonOperator(
    task_id='validate_results',
    python_callable=validate_ttcm_results,
    dag=dag,
    on_failure_callback=send_ttcm_alert,
)

success_email = EmailOperator(
    task_id='success_notification',
    to=['your-email@hsbc.com', 'team-dl@hsbc.com'],  # Replace with actual emails
    subject='TTCM Monthly Execution - SUCCESS - {{ ds }}',
    html_content="""
    <h2>TTCM Monthly Execution Report</h2>

    <p><strong>Execution Date:</strong> {{ ds }}</p>
    <p><strong>Status:</strong> SUCCESS</p>
    <p><strong>DAG:</strong> ttcm_monthly_execution</p>

    <p>TTCM process completed successfully. All mapping comparisons completed.</p>

    <h3>Report Summary:</h3>
    <ul>
        <li>Report 1 (ML15 Changes): Added: {{ task_instance.xcom_pull(task_ids='execute_ttcm')['reports']['r1']['added'] }}, Deleted: {{ task_instance.xcom_pull(task_ids='execute_ttcm')['reports']['r1']['deleted'] }}</li>
        <li>Report 2 (ML15 Attributes): Changed: {{ task_instance.xcom_pull(task_ids='execute_ttcm')['reports']['r2']['changed'] }}</li>
        <li>Report 3 (ML16 Changes): Added: {{ task_instance.xcom_pull(task_ids='execute_ttcm')['reports']['r3']['added'] }}, Deleted: {{ task_instance.xcom_pull(task_ids='execute_ttcm')['reports']['r3']['deleted'] }}</li>
        <li>Report 4 (ML16 Mappings): Changed: {{ task_instance.xcom_pull(task_ids='execute_ttcm')['reports']['r4']['changed'] }}</li>
    </ul>

    <p>Please review the detailed results in the Tally application.</p>
    """,
    dag=dag,
)

# Task dependencies
execute_ttcm >> validate_results >> success_email