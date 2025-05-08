#!/bin/bash
# Setup script for "Analyzing Network Traffic with VPC Flow Logs" project
# This script will create the required infrastructure for the project

# Exit on error
set -e

# Variables
PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"  # Change this to your preferred region
ZONE="${REGION}-a"    # Change this to your preferred zone
VPC_NAME="vpc-net"
SUBNET_NAME="vpc-subnet"
SUBNET_RANGE="10.1.3.0/24"
FIREWALL_NAME="allow-http-ssh"
VM_NAME="web-server"
BIGQUERY_DATASET="bq_vpcflows"

echo "Project ID: ${PROJECT_ID}"
echo "Region: ${REGION}"
echo "Zone: ${ZONE}"

# Create VPC network with Flow Logs enabled
echo "Creating VPC network with Flow Logs enabled..."
gcloud compute networks create ${VPC_NAME} --subnet-mode=custom

# Create subnet with VPC Flow Logs enabled
echo "Creating subnet with VPC Flow Logs enabled..."
gcloud compute networks subnets create ${SUBNET_NAME} \
    --network=${VPC_NAME} \
    --region=${REGION} \
    --range=${SUBNET_RANGE} \
    --enable-flow-logs \
    --logging-aggregation-interval=30s \
    --logging-flow-sampling=0.25

# Create firewall rule for HTTP and SSH
echo "Creating firewall rule..."
gcloud compute firewall-rules create ${FIREWALL_NAME} \
    --network=${VPC_NAME} \
    --allow=tcp:80,tcp:22 \
    --source-ranges=0.0.0.0/0 \
    --target-tags=http-server

# Create VM instance
echo "Creating VM instance..."
gcloud compute instances create ${VM_NAME} \
    --zone=${ZONE} \
    --machine-type=e2-micro \
    --subnet=${SUBNET_NAME} \
    --tags=http-server \
    --metadata=startup-script='#!/bin/bash
      apt-get update
      apt-get install apache2 -y
      echo "<!doctype html><html><body><h1>Hello World!</h1></body></html>" > /var/www/html/index.html'

# Create BigQuery dataset for log export
echo "Creating BigQuery dataset..."
bq --location=${REGION} mk --dataset ${PROJECT_ID}:${BIGQUERY_DATASET}

# Wait for VM to be ready
echo "Waiting for VM to be ready..."
sleep 30

# Get VM's external IP
VM_IP=$(gcloud compute instances describe ${VM_NAME} --zone=${ZONE} --format='get(networkInterfaces[0].accessConfigs[0].natIP)')
echo "Web server is running at: http://${VM_IP}"

# Create log sink to BigQuery
echo "Creating log sink to BigQuery..."
gcloud logging sinks create bq_vpcflows \
    bigquery.googleapis.com/projects/${PROJECT_ID}/datasets/${BIGQUERY_DATASET} \
    --log-filter="resource.type=subnetwork AND logName=projects/${PROJECT_ID}/logs/compute.googleapis.com%2Fvpc_flows"

# Get service account for the sink
SINK_SERVICE_ACCOUNT=$(gcloud logging sinks describe bq_vpcflows --format='get(writerIdentity)')

# Grant permissions to the service account
echo "Granting permissions to the service account..."
bq add-iam-policy-binding \
    --member="${SINK_SERVICE_ACCOUNT}" \
    --role="roles/bigquery.dataEditor" \
    ${PROJECT_ID}:${BIGQUERY_DATASET}

echo "Setup complete!"
echo "Generate traffic to the web server by running:"
echo "for ((i=1;i<=50;i++)); do curl http://${VM_IP}; done"
echo ""
echo "After a few minutes, check BigQuery for logs in dataset: ${BIGQUERY_DATASET}"
