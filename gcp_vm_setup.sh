#!/bin/bash
# GCP VM Setup Script for Tally DQM/TTCM Monthly Execution
# Run this on your GCP VM to set up the Tally application and BigQuery runtime

set -e

echo "=== Tally GCP VM Setup Script ==="
echo "Setting up environment for monthly DQM/TTCM execution..."

# Update system
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install Python 3.9+ and pip
echo "Installing Python and dependencies..."
sudo apt install -y python3 python3-pip python3-venv

# Authenticate with GCP (use service account or default instance credentials)
echo "Setting up GCP authentication..."
# On a GCP VM, the attached service account is used automatically when possible.

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
pip install -r /opt/tally/requirements.txt

# Prepare manual execution scripts
cp /home/$USER/run_dqm.py /opt/tally/ 2>/dev/null || true
cp /home/$USER/run_ttcm.py /opt/tally/ 2>/dev/null || true

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
sudo systemctl enable tally-server
sudo systemctl start tally-server

# Configure firewall
echo "Configuring firewall..."
sudo ufw allow 80/tcp    # Tally web server
sudo ufw --force enable

echo ""
echo "=== GCP Setup Complete! ==="
echo ""
echo "Services running:"
echo "- Tally Web Server: http://YOUR-VM-EXTERNAL-IP"
echo ""
echo "Next steps:"
echo "1. Test the Tally web application"
echo "2. Run DQM/TTCM execution scripts manually"
echo "3. Configure BigQuery credentials if needed"