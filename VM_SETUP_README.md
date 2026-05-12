# Tally DQM/TTCM Execution Setup

This document outlines the setup for DQM (Data Quality Measurement) and TTCM (Transaction Type Code Mapping) execution on an HSBC VM.

## Architecture Overview

```
VM (HSBC Environment)
├── Tally Web Application (Port 80)
│   ├── DQM Interface (dqm.html)
│   └── TTCM Interface (ttcm.html)
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
- Install Python, Google Cloud SDK, and required Python packages
- Set up a virtual environment
- Configure systemd service for the Tally web app
- Enable firewall rules

### 3. Authentication Setup

1. **BigQuery Service Account:**
   ```bash
   scp service-account.json user@vm:/opt/tally/service-account.json
   export GOOGLE_APPLICATION_CREDENTIALS=/opt/tally/service-account.json
   ```

## Manual Execution

Use the manual runner scripts to execute DQM and TTCM.

```bash
# Run DQM manually
python run_dqm.py

# Run TTCM manually
python run_ttcm.py
```

## Monitoring

- Application logs: `/opt/tally/tally.log`
- System logs: `journalctl -u tally-server -f`

## Testing the Setup

### 1. Verify BigQuery Access

```python
from google.cloud import bigquery

client = bigquery.Client()
query = "SELECT COUNT(*) FROM `datarecsv2.dqm_data.camp_transactions`"
result = client.query(query).result()
print(f"DQM test data rows: {list(result)[0][0]}")
```

### 2. Check Web Interface

- Tally App: `http://your-vm-ip`

## Troubleshooting

### Common Issues

1. **BigQuery Authentication Failed**
   ```bash
   gcloud auth activate-service-account --key-file=/opt/tally/service-account.json
   gcloud config set project datarecsv2
   ```

2. **Tally Webserver Not Starting**
   ```bash
   sudo systemctl status tally-server
   sudo journalctl -u tally-server -f
   ```

3. **Dependency Problems**
   - Verify dependencies are installed in the virtual environment
   - Run `pip install -r /opt/tally/requirements.txt`

### Logs and Debugging

```bash
sudo journalctl -u tally-server -f
```

## Maintenance

### Checklist
- [ ] Verify VM has sufficient disk space
- [ ] Check BigQuery quotas and limits
- [ ] Update service account credentials if expired

## Security Considerations

- Service account follows the principle of least privilege
- VM firewall restricts access to necessary ports only
- Logs should be monitored for sensitive data

## Support

For issues:
1. Verify BigQuery permissions
2. Review system logs with `journalctl`
3. Contact HSBC platform team for VM/network issues