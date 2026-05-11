#!/bin/bash
# VM Setup Script for Tally DQM/TTCM Monthly Execution
# Run this on your HSBC VM to set up Airflow and the Tally application

set -e

echo "=== Tally VM Setup Script ==="
echo "Setting up environment for monthly DQM/TTCM execution..."

# Update system
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install Python 3.9+ and pip
echo "Installing Python and dependencies..."
sudo apt install -y python3 python3-pip python3-venv

# Install Google Cloud SDK for BigQuery access
echo "Installing Google Cloud SDK..."
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
sudo apt update && sudo apt install -y google-cloud-sdk

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
pip install google-cloud-bigquery
pip install requests
pip install pandas
pip install apache-airflow

# Install Airflow with email support
pip install apache-airflow[postgres,email]

# Set up Airflow
echo "Setting up Airflow..."
export AIRFLOW_HOME=/opt/tally/airflow
export AIRFLOW__CORE__LOAD_EXAMPLES=False

# Initialize Airflow database
airflow db init

# Create Airflow user (change password!)
airflow users create \
    --username admin \
    --firstname Tally \
    --lastname Admin \
    --role Admin \
    --email your-email@hsbc.com \
    --password changeme123

# Copy application files
echo "Copying application files..."
# Note: You'll need to copy your Tally files to /opt/tally/
# scp -r /path/to/your/tally/* user@vm:/opt/tally/

# Copy DAGs to Airflow dags folder
mkdir -p $AIRFLOW_HOME/dags
cp dqm_monthly_dag.py $AIRFLOW_HOME/dags/
cp ttcm_monthly_dag.py $AIRFLOW_HOME/dags/

# Configure Airflow for email alerts
echo "Configuring Airflow email settings..."
cat >> $AIRFLOW_HOME/airflow.cfg << EOF

# Email configuration
[smtp]
smtp_host = smtp.hsbc.com
smtp_starttls = True
smtp_ssl = False
smtp_user = your-email@hsbc.com
smtp_password = your-password
smtp_port = 587
smtp_mail_from = tally-noreply@hsbc.com

EOF

# Set up BigQuery authentication
echo "Setting up BigQuery authentication..."
echo "Please ensure you have:"
echo "1. Service account JSON key file"
echo "2. Set GOOGLE_APPLICATION_CREDENTIALS environment variable"
echo ""
echo "Example:"
echo "export GOOGLE_APPLICATION_CREDENTIALS=/opt/tally/service-account.json"
echo ""
echo "Copy your service account key to /opt/tally/service-account.json"

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
Environment=GOOGLE_APPLICATION_CREDENTIALS=/opt/tally/service-account.json
ExecStart=/opt/tally/venv/bin/airflow webserver --port 8080
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
Environment=GOOGLE_APPLICATION_CREDENTIALS=/opt/tally/service-account.json
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
Environment=GOOGLE_APPLICATION_CREDENTIALS=/opt/tally/service-account.json
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

# Set up firewall (if needed)
echo "Configuring firewall..."
sudo ufw allow 80/tcp    # Tally web server
sudo ufw allow 8080/tcp  # Airflow web UI
sudo ufw --force enable

echo ""
echo "=== Setup Complete! ==="
echo ""
echo "Services running:"
echo "- Tally Web Server: http://your-vm-ip"
echo "- Airflow Web UI: http://your-vm-ip:8080"
echo "  Username: admin"
echo "  Password: changeme123 (CHANGE THIS!)"
echo ""
echo "Next steps:"
echo "1. Copy your service account JSON to /opt/tally/service-account.json"
echo "2. Update email settings in airflow.cfg"
echo "3. Change the default Airflow password"
echo "4. Test BigQuery connectivity"
echo "5. Run the DAGs manually to verify they work"
echo ""
echo "Monthly execution will start automatically on the 1st of each month."