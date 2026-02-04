#!/bin/bash

# Azure Policy and Alert Deployment Script (Bash version)
# This script deploys Azure policies for expiry monitoring and sets up alert rules

set -e

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    case $color in
        "red") echo -e "\033[31m$message\033[0m" ;;
        "green") echo -e "\033[32m$message\033[0m" ;;
        "yellow") echo -e "\033[33m$message\033[0m" ;;
        "blue") echo -e "\033[34m$message\033[0m" ;;
        *) echo "$message" ;;
    esac
}

# Function to display usage
usage() {
    echo "Usage: $0 -s SUBSCRIPTION_ID -g RESOURCE_GROUP_NAME [-l LOCATION] [-d DAYS_BEFORE_EXPIRY] [-e NOTIFICATION_EMAIL]"
    echo "  -s: Azure subscription ID (required)"
    echo "  -g: Resource group name (required)"
    echo "  -l: Azure region (default: eastus)"
    echo "  -d: Days before expiry to trigger alert (default: 30)"
    echo "  -e: Email address for notifications (optional)"
    echo "  -h: Display this help message"
    exit 1
}

# Parse command line arguments
LOCATION="eastus"
DAYS_BEFORE_EXPIRY=30
NOTIFICATION_EMAIL=""

while getopts "s:g:l:d:e:h" opt; do
    case $opt in
        s) SUBSCRIPTION_ID="$OPTARG" ;;
        g) RESOURCE_GROUP_NAME="$OPTARG" ;;
        l) LOCATION="$OPTARG" ;;
        d) DAYS_BEFORE_EXPIRY="$OPTARG" ;;
        e) NOTIFICATION_EMAIL="$OPTARG" ;;
        h) usage ;;
        \?) echo "Invalid option -$OPTARG" >&2; usage ;;
    esac
done

# Validate required parameters
if [[ -z "$SUBSCRIPTION_ID" || -z "$RESOURCE_GROUP_NAME" ]]; then
    echo "Error: Subscription ID and Resource Group Name are required"
    usage
fi

print_color "blue" "Starting Azure Policy and Alert Deployment..."

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    print_color "red" "Azure CLI is not installed. Please install it first."
    exit 1
fi

# Login to Azure
print_color "yellow" "Logging into Azure..."
az login --output table

# Set subscription context
print_color "yellow" "Setting subscription context..."
az account set --subscription "$SUBSCRIPTION_ID"

# Create resource group if it doesn't exist
print_color "yellow" "Creating resource group: $RESOURCE_GROUP_NAME"
if ! az group show --name "$RESOURCE_GROUP_NAME" &> /dev/null; then
    az group create --name "$RESOURCE_GROUP_NAME" --location "$LOCATION"
    print_color "green" "Resource group created successfully"
else
    print_color "green" "Resource group already exists"
fi

# Deploy policy definitions
print_color "yellow" "Deploying policy definitions..."

# Deploy general expiry policy
GENERAL_POLICY_DEF_ID=$(az policy definition create \
    --name "audit-expiring-resources" \
    --display-name "Audit resources with expiring secrets and certificates" \
    --description "This policy audits Key Vault secrets, certificates, and storage account keys that are expiring within the specified timeframe" \
    --rules "azure-policy-expiry-check.json" \
    --mode All \
    --query 'id' \
    --output tsv)

print_color "green" "General expiry policy definition created: $GENERAL_POLICY_DEF_ID"

# Deploy Azure AD application secrets policy
APP_SECRETS_POLICY_DEF_ID=$(az policy definition create \
    --name "audit-expiring-app-secrets" \
    --display-name "Audit Azure AD Applications with expiring secrets and certificates" \
    --description "This policy audits Azure AD Applications that have secrets or certificates expiring within the specified timeframe" \
    --rules "azure-policy-app-secrets-expiry.json" \
    --mode All \
    --query 'id' \
    --output tsv)

print_color "green" "App secrets policy definition created: $APP_SECRETS_POLICY_DEF_ID"

# Assign policies to subscription
print_color "yellow" "Assigning policies to subscription..."

SUBSCRIPTION_SCOPE="/subscriptions/$SUBSCRIPTION_ID"

# Assign general expiry policy
GENERAL_ASSIGNMENT_ID=$(az policy assignment create \
    --name "audit-expiring-resources-assignment" \
    --display-name "Audit expiring resources assignment" \
    --description "Assignment for auditing expiring resources" \
    --policy "$GENERAL_POLICY_DEF_ID" \
    --scope "$SUBSCRIPTION_SCOPE" \
    --params "{\"daysBeforeExpiry\":{\"value\":$DAYS_BEFORE_EXPIRY},\"effect\":{\"value\":\"audit\"}}" \
    --query 'id' \
    --output tsv)

print_color "green" "General expiry policy assigned: $GENERAL_ASSIGNMENT_ID"

# Assign app secrets policy
APP_SECRETS_ASSIGNMENT_ID=$(az policy assignment create \
    --name "audit-expiring-app-secrets-assignment" \
    --display-name "Audit expiring app secrets assignment" \
    --description "Assignment for auditing expiring Azure AD application secrets" \
    --policy "$APP_SECRETS_POLICY_DEF_ID" \
    --scope "$SUBSCRIPTION_SCOPE" \
    --params "{\"daysBeforeExpiry\":{\"value\":$DAYS_BEFORE_EXPIRY},\"effect\":{\"value\":\"audit\"}}" \
    --query 'id' \
    --output tsv)

print_color "green" "App secrets policy assigned: $APP_SECRETS_ASSIGNMENT_ID"

# Create action group for notifications if email is provided
if [[ -n "$NOTIFICATION_EMAIL" ]]; then
    print_color "yellow" "Creating action group for notifications..."
    
    ACTION_GROUP_NAME="expiry-alerts-action-group"
    
    ACTION_GROUP_ID=$(az monitor action-group create \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --name "$ACTION_GROUP_NAME" \
        --short-name "ExpAlerts" \
        --email-receivers "EmailReceiver" "$NOTIFICATION_EMAIL" \
        --query 'id' \
        --output tsv)
    
    print_color "green" "Action group created: $ACTION_GROUP_ID"
    
    # Deploy alert rule template
    print_color "yellow" "Deploying alert rule..."
    
    ALERT_RULE_ID=$(az deployment group create \
        --resource-group "$RESOURCE_GROUP_NAME" \
        --template-file "alert-rule-template.json" \
        --parameters alertRuleName="expiring-resources-alert" \
                    alertRuleDisplayName="Expiring Resources Alert" \
                    alertRuleDescription="Alert for resources with expiring secrets and certificates" \
                    resourceGroupName="$RESOURCE_GROUP_NAME" \
                    actionGroupId="$ACTION_GROUP_ID" \
                    subscriptionId="$SUBSCRIPTION_ID" \
        --query 'properties.outputs.alertRuleId.value' \
        --output tsv)
    
    print_color "green" "Alert rule deployed: $ALERT_RULE_ID"
fi

print_color "green" "Deployment completed successfully!"
print_color "yellow" "Policy assignments will take effect within 30 minutes."
print_color "yellow" "You can view policy compliance in the Azure portal under Policy -> Compliance."

# Display next steps
print_color "blue" "Next steps:"
echo "1. Wait for 30 minutes for policies to take effect"
echo "2. Check Azure Policy compliance in the portal"
echo "3. Review any non-compliant resources"
echo "4. Set up remediation if needed"
if [[ -n "$NOTIFICATION_EMAIL" ]]; then
    echo "5. Test alert notifications by triggering a policy violation"
fi