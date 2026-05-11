# Tally Application - GCP Deployment Guide

This guide will help you deploy the Tally DQM/TTCM application to your personal GCP project for testing.

## Prerequisites

1. **GCP Account** with billing enabled
2. **Google Cloud SDK** installed locally (`gcloud`)
3. **BigQuery API** enabled in your GCP project
4. **Gmail account** for email alerts (or configure your own SMTP)

## Quick Start

### Step 1: Prepare Your GCP Project

1. **Create/select a GCP project:**
   ```bash
   gcloud projects create your-project-name
   gcloud config set project your-project-name
   ```

2. **Enable required APIs:**
   ```bash
   gcloud services enable bigquery.googleapis.com
   gcloud services enable compute.googleapis.com
   ```

3. **Update configuration:**
   Edit `gcp_config.env` with your project details:
   ```bash
   GCP_PROJECT_ID=your-actual-project-id
   ALERT_EMAIL=your-gmail@gmail.com
   ```

### Step 2: Create BigQuery Test Data

1. **Create datasets:**
   ```bash
   bq mk dqm_data
   bq mk ttcm_data
   ```

2. **Generate test data:**
   ```bash
   python generate_dqm_test_data.py    # Creates 100 rows
   python generate_ttcm_test_data.py   # Creates ~50 ML15 + ~80 ML16 rows
   ```

### Step 3: Deploy to GCP

1. **Make scripts executable:**
   ```bash
   chmod +x deploy_to_gcp.sh gcp_vm_setup.sh deploy_ultra_low_cost.sh
   ```

2. **Run deployment:**
   ```bash
   # Option 1: Standard low-cost (recommended) - ~$12/month
   ./deploy_to_gcp.sh

   # Option 2: Ultra-low cost (testing only) - ~$3/month
   ./deploy_ultra_low_cost.sh
   ```

This will:
- Create a GCP VM instance
- Set up service account with BigQuery permissions
- Copy all files to the VM
- Run the setup script
- Configure firewall rules

### Step 4: Access Your Application

After deployment completes, you'll get output like:
```
VM Details:
- Name: tally-vm
- External IP: 34.123.45.67

Access URLs:
- Tally Application: http://34.123.45.67
- Airflow Dashboard: http://34.123.45.67:8080
  Username: admin
  Password: tally123
```

## Manual Testing

### Test BigQuery Connectivity
```bash
# SSH to your VM
gcloud compute ssh tally-vm --zone=us-central1-a

# Test BigQuery access
cd /opt/tally
source venv/bin/activate
python test_setup.py
```

### Test DAGs Manually
```bash
# In Airflow UI, unpause and trigger DAGs
# Or via command line:
airflow dags unpause dqm_monthly_execution
airflow dags trigger dqm_monthly_execution
```

### Monitor Logs
```bash
# View Airflow logs
tail -f /opt/tally/airflow/logs/dag_processor_manager/dag_processor_manager.log

# View application logs
sudo journalctl -u tally-server -f
```

## Configuration Updates

### Update BigQuery Project in DAGs
Edit the DAG files to use your project ID:
```python
PROJECT  = 'your-gcp-project-id'  # Update this in both DAGs
```

### Configure Email Alerts
Update `/opt/tally/airflow/airflow.cfg` on the VM:
```ini
[smtp]
smtp_user = your-gmail@gmail.com
smtp_password = your-gmail-app-password
```

### Custom Domain (Optional)
If you want a custom domain:
1. Reserve a domain name
2. Create DNS A record pointing to VM external IP
3. Update firewall rules if needed

## Cost Optimization Options

| Option | VM Type | Monthly Cost | Use Case | Reliability |
|--------|---------|-------------|----------|-------------|
| **Standard** | e2-small | ~$12 | Development/Testing | High |
| **Ultra-Low** | e2-micro (spot) | ~$3 | Quick testing only | Low (can be terminated) |
| **Original** | e2-medium | ~$25 | Production | High |

**Recommended:** Use e2-small for development testing, then scale up for production.

## Cleanup

When done testing:
```bash
# Delete VM
gcloud compute instances delete tally-vm --zone=us-central1-a

# Delete firewall rules
gcloud compute firewall-rules delete allow-tally-http allow-airflow

# Delete service account (optional)
gcloud iam service-accounts delete tally-service-account@your-project.iam.gserviceaccount.com
```

## Troubleshooting

### VM Creation Issues
```bash
# Check VM status
gcloud compute instances list

# View serial console output
gcloud compute instances get-serial-port-output tally-vm --zone=us-central1-a
```

### BigQuery Permission Issues
```bash
# Check service account permissions
gcloud projects get-iam-policy your-project --flatten="bindings[].members" --filter="bindings.members:serviceAccount:tally-service-account@your-project.iam.gserviceaccount.com"
```

### Airflow Issues
```bash
# Restart Airflow services
sudo systemctl restart airflow-webserver airflow-scheduler

# Check Airflow logs
sudo journalctl -u airflow-scheduler -f
```

## Next Steps for HSBC Deployment

Once tested in GCP, adapt for HSBC:

1. **Replace GCP VM** with HSBC VM
2. **Update authentication** (service account → HSBC credentials)
3. **Configure HSBC SMTP** for email alerts
4. **Update firewall rules** per HSBC policies
5. **Add monitoring** per HSBC standards

The core application and DAGs will work the same way!