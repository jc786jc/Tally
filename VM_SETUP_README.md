# Tally DQM/TTCM Monthly Execution Setup

This document outlines the setup for automated monthly execution of DQM (Data Quality Measurement) and TTCM (Transaction Type Code Mapping) processes using Apache Airflow on an HSBC VM.

## Architecture Overview

```
VM (HSBC Environment)
├── Tally Web Application (Port 80)
│   ├── DQM Interface (dqm.html)
│   └── TTCM Interface (ttcm.html)
├── Airflow Scheduler
│   ├── dqm_monthly_dag.py (Runs 1st of month, 2 AM UTC)
│   └── ttcm_monthly_dag.py (Runs 1st of month, 3 AM UTC)
└── BigQuery (datarecsv2 project)
    ├── dqm_data.camp_transactions (Test data)
    ├── dqm_data.ref_currency_codes (Reference data)
    ├── ttcm_data.sscrtyp_prev/cur (ML15 data)
    └── ttcm_data.sscrcep_prev/cur (ML16 data)
```

## Prerequisites

- HSBC VM with Ubuntu/Debian Linux
- Access to BigQuery project `datarecsv2`
- Service account with BigQuery access
- SMTP server access for email alerts

## One-Time Setup

### 1. Generate Test Data (Run Once)

Execute these scripts once to create test datasets:

```bash
# Generate DQM test data
python generate_dqm_test_data.py

# Generate TTCM test data
python generate_ttcm_test_data.py
```

### 2. VM Setup

Run the automated setup script:

```bash
chmod +x vm_setup.sh
sudo ./vm_setup.sh
```

This will:
- Install Python, Google Cloud SDK, and Airflow
- Set up virtual environment
- Configure systemd services
- Enable firewall rules

### 3. Authentication Setup

1. **BigQuery Service Account:**
   ```bash
   # Copy your service account JSON key to the VM
   scp service-account.json user@vm:/opt/tally/service-account.json

   # Set environment variable
   export GOOGLE_APPLICATION_CREDENTIALS=/opt/tally/service-account.json
   ```

2. **Airflow Admin Password:**
   ```bash
   # Change default password
   cd /opt/tally
   source venv/bin/activate
   airflow users create --username admin --firstname Tally --lastname Admin \
       --role Admin --email your-email@hsbc.com --password <secure-password>
   ```

### 4. Email Configuration

Update `/opt/tally/airflow/airflow.cfg`:

```ini
[smtp]
smtp_host = smtp.hsbc.com
smtp_starttls = True
smtp_ssl = False
smtp_user = your-email@hsbc.com
smtp_password = your-smtp-password
smtp_port = 587
smtp_mail_from = tally-noreply@hsbc.com
```

## Monthly Execution Schedule

- **DQM DAG**: Runs 1st of every month at 2:00 AM UTC
- **TTCM DAG**: Runs 1st of every month at 3:00 AM UTC

### DAG Structure

#### DQM DAG (`dqm_monthly_dag.py`)
```
execute_dqm → validate_results → success_notification
```

#### TTCM DAG (`ttcm_monthly_dag.py`)
```
execute_ttcm → validate_results → success_notification
```

## Monitoring & Alerting

### Email Notifications
- **Success**: Summary email with execution results
- **Failure**: Alert email with error details and logs

### Airflow Web UI
Access at `http://your-vm-ip:8080` to:
- Monitor DAG runs
- View logs
- Manually trigger executions
- Check task status

### Log Locations
- Airflow logs: `/opt/tally/airflow/logs/`
- Application logs: `/opt/tally/tally.log`
- System logs: `journalctl -u airflow-webserver/scheduler`

## Testing the Setup

### 1. Manual DAG Execution
```bash
# Test DQM DAG
airflow dags unpause dqm_monthly_execution
airflow dags trigger dqm_monthly_execution

# Test TTCM DAG
airflow dags unpause ttcm_monthly_execution
airflow dags trigger ttcm_monthly_execution
```

### 2. Verify BigQuery Access
```python
from google.cloud import bigquery

client = bigquery.Client()
query = "SELECT COUNT(*) FROM `datarecsv2.dqm_data.camp_transactions`"
result = client.query(query).result()
print(f"DQM test data rows: {list(result)[0][0]}")
```

### 3. Check Web Interfaces
- Tally App: `http://your-vm-ip`
- Airflow UI: `http://your-vm-ip:8080`

## Troubleshooting

### Common Issues

1. **BigQuery Authentication Failed**
   ```bash
   # Verify service account
   gcloud auth activate-service-account --key-file=/opt/tally/service-account.json
   gcloud config set project datarecsv2
   ```

2. **Airflow Webserver Not Starting**
   ```bash
   sudo systemctl status airflow-webserver
   sudo journalctl -u airflow-webserver -f
   ```

3. **DAG Import Errors**
   - Check Python path in DAG files
   - Verify dependencies are installed in virtual environment

4. **Email Not Sending**
   - Verify SMTP settings in `airflow.cfg`
   - Check firewall allows SMTP port (587)

### Logs and Debugging
```bash
# View Airflow scheduler logs
sudo journalctl -u airflow-scheduler -f

# View specific DAG run logs
airflow dags show dqm_monthly_execution
airflow tasks logs dqm_monthly_execution execute_dqm <execution-date>
```

## Maintenance

### Monthly Checklist
- [ ] Verify VM has sufficient disk space
- [ ] Check BigQuery quotas and limits
- [ ] Review failed executions in Airflow UI
- [ ] Update service account credentials if expired

### Updates
```bash
# Update Airflow
cd /opt/tally
source venv/bin/activate
pip install --upgrade apache-airflow

# Restart services
sudo systemctl restart airflow-webserver airflow-scheduler
```

## Security Considerations

- Service account follows principle of least privilege
- VM firewall restricts access to necessary ports only
- Airflow web UI protected by authentication
- Logs rotated and monitored for sensitive data

## Support

For issues:
1. Check Airflow logs and web UI
2. Verify BigQuery permissions
3. Review system logs with `journalctl`
4. Contact HSBC platform team for VM/network issues