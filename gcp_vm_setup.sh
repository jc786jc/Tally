#!/bin/bash
# GCP VM Setup Script for Tally DQM/TTCM Monthly Execution
# Run this on your GCP VM to set up Airflow and the Tally application

set -e

echo "=== Tally GCP VM Setup Script ==="
echo "Setting up environment for monthly DQM/TTCM execution..."

# Update system
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install Python 3.9+ and pip
echo "Installing Python and dependencies..."
sudo apt install -y python3 python3-pip python3-venv

# Install Google Cloud SDK (already installed on GCP VMs, but ensure latest)
echo "Updating Google Cloud SDK..."
sudo apt install -y google-cloud-sdk

# Authenticate with GCP (use service account or user credentials)
echo "Setting up GCP authentication..."
# Note: On GCP VM, you can use instance service account or user auth

# Create application directory
echo "Creating application directory..."
sudo mkdir -p /opt/tally
sudo chown $USER:$USER /opt/tally

# Set up Python virtual environment
echo "Setting up Python virtual environment..."
cd /opt/tally
python3 -m venv venv
source venv/bin/activate

# Install Python dependencies
echo "Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

# Set up Airflow
echo "Setting up Airflow..."
export AIRFLOW_HOME=/opt/tally/airflow
export AIRFLOW__CORE__LOAD_EXAMPLES=False

# Initialize Airflow database
airflow db init

# Create Airflow user
airflow users create \
    --username admin \
    --firstname Tally \
    --lastname Admin \
    --role Admin \
    --email admin@tally.local \
    --password tally123

# Copy DAGs to Airflow dags folder
mkdir -p $AIRFLOW_HOME/dags
cp dqm_monthly_dag.py $AIRFLOW_HOME/dags/
cp ttcm_monthly_dag.py $AIRFLOW_HOME/dags/

# Configure Airflow for GCP
echo "Configuring Airflow for GCP..."
cat >> $AIRFLOW_HOME/airflow.cfg << EOF

# GCP Configuration
[core]
dags_folder = /opt/tally/airflow/dags
load_examples = False

# Email configuration (using Gmail for testing - replace with your SMTP)
[smtp]
smtp_host = smtp.gmail.com
smtp_starttls = True
smtp_ssl = False
smtp_user = your-gmail@gmail.com
smtp_password = your-app-password
smtp_port = 587
smtp_mail_from = tally-noreply@gmail.com

# Webserver configuration
[webserver]
web_server_host = 0.0.0.0
web_server_port = 8080

EOF

# Create systemd service for Airflow webserver
echo "Creating systemd service for Airflow..."
sudo tee /etc/systemd/system/airflow-webserver.service > /dev/null << EOF
[Unit]
Description=Airflow Webserver
After=network.target

[Service]
User=$USER
Group=$USER
WorkingDirectory=/opt/tally
Environment=AIRFLOW_HOME=/opt/tally/airflow
ExecStart=/opt/tally/venv/bin/airflow webserver
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Create systemd service for Airflow scheduler
sudo tee /etc/systemd/system/airflow-scheduler.service > /dev/null << EOF
[Unit]
Description=Airflow Scheduler
After=network.target

[Service]
User=$USER
Group=$USER
WorkingDirectory=/opt/tally
Environment=AIRFLOW_HOME=/opt/tally/airflow
ExecStart=/opt/tally/venv/bin/airflow scheduler
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Create systemd service for Tally web server
sudo tee /etc/systemd/system/tally-server.service > /dev/null << EOF
[Unit]
Description=Tally Web Server
After=network.target

[Service]
User=$USER
Group=$USER
WorkingDirectory=/opt/tally
ExecStart=/opt/tally/venv/bin/python server.py --prod
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Enable and start services
echo "Enabling and starting services..."
sudo systemctl daemon-reload
sudo systemctl enable airflow-webserver
sudo systemctl enable airflow-scheduler
sudo systemctl enable tally-server

sudo systemctl start airflow-webserver
sudo systemctl start airflow-scheduler
sudo systemctl start tally-server

# Configure firewall
echo "Configuring firewall..."
sudo ufw allow 80/tcp    # Tally web server
sudo ufw allow 8080/tcp  # Airflow web UI
sudo ufw --force enable

echo ""
echo "=== GCP Setup Complete! ==="
echo ""
echo "Services running:"
echo "- Tally Web Server: http://YOUR-VM-EXTERNAL-IP"
echo "- Airflow Web UI: http://YOUR-VM-EXTERNAL-IP:8080"
echo "  Username: admin"
echo "  Password: tally123"
echo ""
echo "Next steps:"
echo "1. Update BigQuery project ID in the DAG files"
echo "2. Configure email settings in airflow.cfg"
echo "3. Test BigQuery connectivity"
echo "4. Run the DAGs manually to verify they work"
echo ""
echo "Monthly execution will start automatically on the 1st of each month."