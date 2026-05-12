#!/bin/bash
# VM Setup Script for Tally DQM/TTCM Monthly Execution
# Run this on your HSBC VM to set up the Tally application and BigQuery runtime

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
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list
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
sudo systemctl enable tally-server
sudo systemctl start tally-server

# Set up firewall (if needed)
echo "Configuring firewall..."
sudo ufw allow 80/tcp    # Tally web server
sudo ufw --force enable

echo ""
echo "=== Setup Complete! ==="
echo ""
echo "Services running:"
echo "- Tally Web Server: http://your-vm-ip"
echo ""
echo "Next steps:"
echo "1. Copy your service account JSON to /opt/tally/service-account.json"
echo "2. Test BigQuery connectivity"
echo "3. Run DQM/TTCM execution scripts manually"
echo ""