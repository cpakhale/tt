# Azure Policy and Alert Deployment Script
# This script deploys Azure policies for expiry monitoring and sets up alert rules

param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [string]$Location = "East US",
    
    [Parameter(Mandatory = $false)]
    [int]$DaysBeforeExpiry = 30,
    
    [Parameter(Mandatory = $false)]
    [string]$NotificationEmail = ""
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Function to write colored output
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

# Connect to Azure
Write-ColorOutput "Connecting to Azure..." "Yellow"
Connect-AzAccount -SubscriptionId $SubscriptionId

# Set subscription context
Set-AzContext -SubscriptionId $SubscriptionId

# Create resource group if it doesn't exist
Write-ColorOutput "Creating resource group: $ResourceGroupName" "Yellow"
$resourceGroup = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
if (-not $resourceGroup) {
    New-AzResourceGroup -Name $ResourceGroupName -Location $Location
    Write-ColorOutput "Resource group created successfully" "Green"
} else {
    Write-ColorOutput "Resource group already exists" "Green"
}

# Deploy policy definitions
Write-ColorOutput "Deploying policy definitions..." "Yellow"

# Deploy general expiry policy
$generalPolicyDef = New-AzPolicyDefinition `
    -Name "audit-expiring-resources" `
    -DisplayName "Audit resources with expiring secrets and certificates" `
    -Description "This policy audits Key Vault secrets, certificates, and storage account keys that are expiring within the specified timeframe" `
    -Policy (Get-Content -Path "azure-policy-expiry-check.json" -Raw) `
    -Mode All

Write-ColorOutput "General expiry policy definition created: $($generalPolicyDef.PolicyDefinitionId)" "Green"

# Deploy Azure AD application secrets policy
$appSecretsPolicyDef = New-AzPolicyDefinition `
    -Name "audit-expiring-app-secrets" `
    -DisplayName "Audit Azure AD Applications with expiring secrets and certificates" `
    -Description "This policy audits Azure AD Applications that have secrets or certificates expiring within the specified timeframe" `
    -Policy (Get-Content -Path "azure-policy-app-secrets-expiry.json" -Raw) `
    -Mode All

Write-ColorOutput "App secrets policy definition created: $($appSecretsPolicyDef.PolicyDefinitionId)" "Green"

# Assign policies to subscription
Write-ColorOutput "Assigning policies to subscription..." "Yellow"

$subscriptionScope = "/subscriptions/$SubscriptionId"

# Assign general expiry policy
$generalAssignment = New-AzPolicyAssignment `
    -Name "audit-expiring-resources-assignment" `
    -DisplayName "Audit expiring resources assignment" `
    -Description "Assignment for auditing expiring resources" `
    -PolicyDefinition $generalPolicyDef `
    -Scope $subscriptionScope `
    -PolicyParameterObject @{
        daysBeforeExpiry = $DaysBeforeExpiry
        effect = "audit"
    }

Write-ColorOutput "General expiry policy assigned: $($generalAssignment.PolicyAssignmentId)" "Green"

# Assign app secrets policy
$appSecretsAssignment = New-AzPolicyAssignment `
    -Name "audit-expiring-app-secrets-assignment" `
    -DisplayName "Audit expiring app secrets assignment" `
    -Description "Assignment for auditing expiring Azure AD application secrets" `
    -PolicyDefinition $appSecretsPolicyDef `
    -Scope $subscriptionScope `
    -PolicyParameterObject @{
        daysBeforeExpiry = $DaysBeforeExpiry
        effect = "audit"
    }

Write-ColorOutput "App secrets policy assigned: $($appSecretsAssignment.PolicyAssignmentId)" "Green"

# Create action group for notifications if email is provided
if ($NotificationEmail) {
    Write-ColorOutput "Creating action group for notifications..." "Yellow"
    
    $actionGroupName = "expiry-alerts-action-group"
    $emailReceiver = New-AzActionGroupReceiver -Name "EmailReceiver" -EmailReceiver -EmailAddress $NotificationEmail
    
    $actionGroup = Set-AzActionGroup -ResourceGroupName $ResourceGroupName -Name $actionGroupName -ShortName "ExpAlerts" -Receiver $emailReceiver
    
    Write-ColorOutput "Action group created: $($actionGroup.Id)" "Green"
    
    # Deploy alert rule template
    Write-ColorOutput "Deploying alert rule..." "Yellow"
    
    $alertDeployment = New-AzResourceGroupDeployment `
        -ResourceGroupName $ResourceGroupName `
        -TemplateFile "alert-rule-template.json" `
        -alertRuleName "expiring-resources-alert" `
        -alertRuleDisplayName "Expiring Resources Alert" `
        -alertRuleDescription "Alert for resources with expiring secrets and certificates" `
        -resourceGroupName $ResourceGroupName `
        -actionGroupId $actionGroup.Id `
        -subscriptionId $SubscriptionId
    
    Write-ColorOutput "Alert rule deployed: $($alertDeployment.Outputs.alertRuleId.Value)" "Green"
}

Write-ColorOutput "Deployment completed successfully!" "Green"
Write-ColorOutput "Policy assignments will take effect within 30 minutes." "Yellow"
Write-ColorOutput "You can view policy compliance in the Azure portal under Policy -> Compliance." "Yellow"