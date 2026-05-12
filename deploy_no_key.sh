#!/bin/bash
# Alternative GCP Deployment Script - Uses VM Service Account Instead of JSON Key
# This avoids the service account key creation issue

set -e

# Configuration - Update these values
PROJECT_ID="datarecsv2"  # Replace with your GCP project ID
VM_NAME="tally-vm"
ZONE="us-central1-a"
MACHINE_TYPE="e2-small"  # Changed from e2-medium for 50% cost reduction
SERVICE_ACCOUNT="tally-service-account@${PROJECT_ID}.iam.gserviceaccount.com"

echo "=== GCP Tally Deployment Script (No JSON Key) ==="
echo "Project: $PROJECT_ID"
echo "VM: $VM_NAME (using VM service account)"
echo ""

# Check if gcloud is installed and authenticated
echo "Checking GCP authentication..."
gcloud auth list --filter=status:ACTIVE --format="value(account)"

if [ $? -ne 0 ]; then
    echo "❌ Not authenticated with GCP. Please run:"
    echo "gcloud auth login"
    exit 1
fi

# Set project
echo "Setting GCP project..."
gcloud config set project $PROJECT_ID

# Create service account if it doesn't exist
echo "Creating/checking service account..."
if ! gcloud iam service-accounts describe $SERVICE_ACCOUNT >/dev/null 2>&1; then
    gcloud iam service-accounts create tally-service-account \
        --description="Service account for Tally application" \
        --display-name="Tally Service Account"
fi

# Grant BigQuery permissions
echo "Granting BigQuery permissions..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT" \
    --role="roles/bigquery.dataViewer"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:$SERVICE_ACCOUNT" \
    --role="roles/bigquery.jobUser"

# Create VM instance (using service account, no JSON key needed)
echo "Creating VM instance..."
gcloud compute instances create $VM_NAME \
    --zone=$ZONE \
    --machine-type=$MACHINE_TYPE \
    --network-tier=PREMIUM \
    --maintenance-policy=MIGRATE \
    --image=ubuntu-2204-jammy-v20240126 \
    --image-project=ubuntu-os-cloud \
    --boot-disk-size=30GB \
    --boot-disk-type=pd-standard \
    --boot-disk-device-name=$VM_NAME \
    --service-account=$SERVICE_ACCOUNT \
    --scopes=https://www.googleapis.com/auth/cloud-platform \
    --tags=tally-server \
    --metadata=startup-script="#!/bin/bash
sudo apt update
sudo apt install -y python3 python3-pip git
"

# Wait for VM to be ready
echo "Waiting for VM to be ready..."
sleep 45
gcloud compute instances get-serial-port-output $VM_NAME --zone=$ZONE --project=$PROJECT_ID

# Copy files to VM (no service account key needed)
echo "Copying application files to VM..."
VM_IP=$(gcloud compute instances describe $VM_NAME --zone=$ZONE --format="get(networkInterfaces[0].accessConfigs[0].natIP)")

# Copy all necessary files (excluding the key file)
gcloud compute scp --zone=$ZONE --recurse . $VM_NAME:~/

# Run setup on VM
echo "Running setup on VM..."
gcloud compute ssh $VM_NAME --zone=$ZONE --command="
cd ~
chmod +x gcp_vm_setup.sh
sudo ./gcp_vm_setup.sh
"

# Create firewall rules
echo "Creating firewall rules..."
gcloud compute firewall-rules create allow-tally-http \
    --allow tcp:80 \
    --source-ranges 0.0.0.0/0 \
    --target-tags tally-server \
    --description="Allow HTTP traffic to Tally web server"

echo ""
echo "=== GCP Deployment Complete! ==="
echo ""
echo "VM Details:"
echo "- Name: $VM_NAME"
echo "- Zone: $ZONE"
echo "- External IP: $VM_IP"
echo ""
echo "Access URLs:"
echo "- Tally Application: http://$VM_IP"
echo ""
echo "Note: This deployment uses the VM's attached service account."
echo "No JSON key file was created - BigQuery will use default credentials."
echo ""
echo "To connect to VM: gcloud compute ssh $VM_NAME --zone=$ZONE"