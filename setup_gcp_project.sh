#!/bin/bash
# GCP Project Setup Script
# Run this locally to prepare your GCP project for Tally deployment

set -e

echo "=== GCP Project Setup for Tally ==="

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "❌ gcloud CLI not found. Please install Google Cloud SDK:"
    echo "https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Check authentication
echo "Checking GCP authentication..."
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | head -n 1 > /dev/null; then
    echo "❌ Not authenticated with GCP. Please run:"
    echo "gcloud auth login"
    exit 1
fi

echo "✅ GCP authentication confirmed"

# Project ID
PROJECT_ID="datarecsv2"

# Set project
echo "Setting project to: $PROJECT_ID"
gcloud config set project "$PROJECT_ID"

# Verify project exists
if ! gcloud projects describe "$PROJECT_ID" > /dev/null 2>&1; then
    echo "❌ Project $PROJECT_ID not found or you don't have access"
    exit 1
fi

echo "✅ Project access confirmed"

# Enable required APIs
echo "Enabling required APIs..."
gcloud services enable bigquery.googleapis.com
gcloud services enable compute.googleapis.com
echo "✅ APIs enabled"

# Create BigQuery datasets
echo "Creating BigQuery datasets..."
bq mk --project_id="$PROJECT_ID" dqm_data
bq mk --project_id="$PROJECT_ID" ttcm_data
echo "✅ BigQuery datasets created"

# Update configuration file
echo "Updating configuration file..."
sed -i.bak "s/your-gcp-project-id/$PROJECT_ID/g" gcp_config.env && rm -f gcp_config.env.bak
echo "✅ Configuration updated"

# Generate test data (optional)
read -p "Generate test data now? (y/n): " GENERATE_DATA
if [[ $GENERATE_DATA =~ ^[Yy]$ ]]; then
    echo "Generating test data..."
    python generate_dqm_test_data.py
    python generate_ttcm_test_data.py
    echo "✅ Test data generated"
fi

echo ""
echo "=== GCP Project Setup Complete! ==="
echo ""
echo "Project: $PROJECT_ID"
echo "Datasets: dqm_data, ttcm_data"
echo ""
echo "Next steps:"
echo "1. Run: ./deploy_to_gcp.sh"
echo ""
echo "Configuration file: gcp_config.env"