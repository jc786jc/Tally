#!/bin/bash
# ULTRA-LOW COST GCP Deployment Script for Tally Application
# Uses e2-micro + spot instances for maximum cost reduction

set -e

# Configuration - Update these values
PROJECT_ID="your-gcp-project-id"  # Replace with your GCP project ID
VM_NAME="tally-micro-vm"
ZONE="us-central1-a"
MACHINE_TYPE="e2-micro"  # Ultra-low cost: ~$3/month
BOOT_DISK_SIZE="20GB"    # Minimal disk

echo "=== ULTRA-LOW COST GCP Tally Deployment ==="
echo "Using e2-micro + spot instance for maximum cost savings"
echo "Project: $PROJECT_ID"
echo "VM: $VM_NAME (e2-micro spot)"
echo ""

# Check if gcloud is authenticated
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
if ! gcloud iam service-accounts describe tally-service-account@$PROJECT_ID.iam.gserviceaccount.com >/dev/null 2>&1; then
    gcloud iam service-accounts create tally-service-account \
        --description="Service account for Tally application" \
        --display-name="Tally Service Account"
fi

# Create key for service account
echo "Creating service account key..."
gcloud iam service-accounts keys create tally-key.json \
    --iam-account=tally-service-account@$PROJECT_ID.iam.gserviceaccount.com

# Grant BigQuery permissions
echo "Granting BigQuery permissions..."
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:tally-service-account@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/bigquery.dataViewer"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:tally-service-account@$PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/bigquery.jobUser"

# Create ULTRA-LOW COST spot VM instance
echo "Creating ultra-low cost spot VM instance..."
gcloud compute instances create $VM_NAME \
    --zone=$ZONE \
    --machine-type=$MACHINE_TYPE \
    --provisioning-model=SPOT \
    --instance-termination-action=STOP \
    --max-run-duration=86400s \
    --network-tier=PREMIUM \
    --maintenance-policy=MIGRATE \
    --image=ubuntu-2204-jammy-v20240126 \
    --image-project=ubuntu-os-cloud \
    --boot-disk-size=$BOOT_DISK_SIZE \
    --boot-disk-type=pd-standard \
    --boot-disk-device-name=$VM_NAME \
    --service-account=tally-service-account@$PROJECT_ID.iam.gserviceaccount.com \
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

# Copy files to VM
echo "Copying application files to VM..."
VM_IP=$(gcloud compute instances describe $VM_NAME --zone=$ZONE --format="get(networkInterfaces[0].accessConfigs[0].natIP)")

# Copy all necessary files
gcloud compute scp --zone=$ZONE --recurse . $VM_NAME:~/

# Copy service account key
gcloud compute scp --zone=$ZONE tally-key.json $VM_NAME:~/service-account.json

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

gcloud compute firewall-rules create allow-airflow \
    --allow tcp:8080 \
    --source-ranges 0.0.0.0/0 \
    --target-tags tally-server \
    --description="Allow HTTP traffic to Airflow web UI"

echo ""
echo "=== ULTRA-LOW COST Deployment Complete! ==="
echo ""
echo "VM Details:"
echo "- Name: $VM_NAME"
echo "- Zone: $ZONE"
echo "- Type: e2-micro (SPOT INSTANCE - may be terminated)"
echo "- External IP: $VM_IP"
echo ""
echo "⚠️  WARNING: This is a SPOT INSTANCE"
echo "   - Costs ~$3/month (90% savings!)"
echo "   - May be terminated by GCP at any time"
echo "   - Maximum runtime: 24 hours"
echo "   - Use for testing only, not production!"
echo ""
echo "Access URLs:"
echo "- Tally Application: http://$VM_IP"
echo "- Airflow Dashboard: http://$VM_IP:8080"
echo "  Username: admin"
echo "  Password: tally123"
echo ""
echo "To connect: gcloud compute ssh $VM_NAME --zone=$ZONE"
echo ""
echo "To restart if terminated: ./deploy_ultra_low_cost.sh"