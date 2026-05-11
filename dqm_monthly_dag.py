"""
Airflow DAG for monthly DQM (Data Quality Measurement) execution
Runs on the 1st of every month at 2 AM UTC
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
    'dqm_monthly_execution',
    default_args=default_args,
    description='Monthly DQM execution on existing test data',
    schedule_interval='0 2 1 * *',  # 1st of every month at 2 AM
    catchup=False,
    tags=['tally', 'dqm', 'monthly'],
)

def execute_dqm_process():
    """
    Execute DQM process on existing test data
    This function will call the DQM logic (adapt based on your implementation)
    """
    try:
        logging.info("Starting DQM execution...")

        # TODO: Replace with actual DQM execution logic
        # This could be:
        # 1. Direct Python function call if DQM logic is available
        # 2. API call to your server
        # 3. BigQuery stored procedure execution

        # Example: If you have a Python function to run DQM
        # from your_dqm_module import run_dqm
        # result = run_dqm()

        # For now, simulate the process
        logging.info("Running DQM rules validation...")
        logging.info("Checking completeness, conformity, specificity, reference...")

        # Simulate processing time
        import time
        time.sleep(30)  # Replace with actual processing

        logging.info("DQM execution completed successfully")
        return {"status": "success", "message": "DQM completed"}

    except Exception as e:
        logging.error(f"DQM execution failed: {str(e)}")
        raise

def validate_dqm_results():
    """
    Validate DQM results and check for issues
    """
    try:
        logging.info("Validating DQM results...")

        # TODO: Add validation logic
        # Check if results meet quality thresholds
        # Verify data integrity
        # Check for critical failures

        logging.info("DQM results validation completed")
        return True

    except Exception as e:
        logging.error(f"DQM validation failed: {str(e)}")
        raise

def send_dqm_alert(context):
    """
    Send alert email for DQM execution
    """
    task_instance = context['task_instance']
    execution_date = context['execution_date']

    subject = f"DQM Monthly Execution Alert - {execution_date.strftime('%Y-%m-%d')}"
    body = f"""
    DQM Monthly Execution Report

    Execution Date: {execution_date.strftime('%Y-%m-%d %H:%M:%S UTC')}
    DAG: dqm_monthly_execution
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
execute_dqm = PythonOperator(
    task_id='execute_dqm',
    python_callable=execute_dqm_process,
    dag=dag,
    on_failure_callback=send_dqm_alert,
)

validate_results = PythonOperator(
    task_id='validate_results',
    python_callable=validate_dqm_results,
    dag=dag,
    on_failure_callback=send_dqm_alert,
)

success_email = EmailOperator(
    task_id='success_notification',
    to=['your-email@hsbc.com', 'team-dl@hsbc.com'],  # Replace with actual emails
    subject='DQM Monthly Execution - SUCCESS - {{ ds }}',
    html_content="""
    <h2>DQM Monthly Execution Report</h2>

    <p><strong>Execution Date:</strong> {{ ds }}</p>
    <p><strong>Status:</strong> SUCCESS</p>
    <p><strong>DAG:</strong> dqm_monthly_execution</p>

    <p>DQM process completed successfully. All quality checks passed.</p>

    <p>Please review the results in the Tally application.</p>
    """,
    dag=dag,
)

# Task dependencies
execute_dqm >> validate_results >> success_email