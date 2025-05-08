#!/bin/bash
# Cleanup script for "Analyzing Network Traffic with VPC Flow Logs" project
# This script will delete all resources created for the project

# Exit on error
set -e

# Variables
PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"  # Change this to your preferred region
ZONE="${REGION}-a"    # Change this to your preferred zone
VPC_NAME="vpc-net"
SUBNET_NAME="vpc-subnet"
FIREWALL_NAME="allow-http-ssh"
VM_NAME="web-server"
BIGQUERY_DATASET="bq_vpcflows"

echo "Project ID: ${PROJECT_ID}"
echo "Region: ${REGION}"
echo "Zone: ${ZONE}"

# Confirm before proceeding
read -p "This will delete all resources created for the project. Are you sure? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "Aborted."
    exit 1
fi

# Delete log sink
echo "Deleting log sink..."
gcloud logging sinks delete bq_vpcflows --quiet || echo "Log sink already deleted"

# Delete VM instance
echo "Deleting VM instance..."
gcloud compute instances delete ${VM_NAME} --zone=${ZONE} --quiet || echo "VM already deleted"

# Delete firewall rule
echo "Deleting firewall rule..."
gcloud compute firewall-rules delete ${FIREWALL_NAME} --quiet || echo "Firewall rule already deleted"

# Delete subnet
echo "Deleting subnet..."
gcloud compute networks subnets delete ${SUBNET_NAME} --region=${REGION} --quiet || echo "Subnet already deleted"

# Delete VPC network
echo "Deleting VPC network..."
gcloud compute networks delete ${VPC_NAME} --quiet || echo "VPC network already deleted"

# Delete BigQuery dataset
echo "Deleting BigQuery dataset..."
bq rm -r -f -d ${PROJECT_ID}:${BIGQUERY_DATASET} || echo "BigQuery dataset already deleted"

echo "Cleanup complete!"
