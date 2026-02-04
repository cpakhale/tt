# Validation Script for Azure Policy Expiry Monitoring
# This script validates the deployed policies and alert rules

param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName
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

# Function to validate policy definition
function Test-PolicyDefinition {
    param(
        [string]$PolicyName
    )
    
    try {
        $policy = Get-AzPolicyDefinition -Name $PolicyName -ErrorAction SilentlyContinue
        if ($policy) {
            Write-ColorOutput "✓ Policy definition '$PolicyName' exists" "Green"
            return $true
        } else {
            Write-ColorOutput "✗ Policy definition '$PolicyName' not found" "Red"
            return $false
        }
    } catch {
        Write-ColorOutput "✗ Error checking policy definition '$PolicyName': $($_.Exception.Message)" "Red"
        return $false
    }
}

# Function to validate policy assignment
function Test-PolicyAssignment {
    param(
        [string]$AssignmentName,
        [string]$Scope
    )
    
    try {
        $assignment = Get-AzPolicyAssignment -Name $AssignmentName -Scope $Scope -ErrorAction SilentlyContinue
        if ($assignment) {
            Write-ColorOutput "✓ Policy assignment '$AssignmentName' exists" "Green"
            Write-ColorOutput "  Scope: $($assignment.Properties.Scope)" "Gray"
            Write-ColorOutput "  Effect: $($assignment.Properties.Parameters.effect.value)" "Gray"
            Write-ColorOutput "  Days before expiry: $($assignment.Properties.Parameters.daysBeforeExpiry.value)" "Gray"
            return $true
        } else {
            Write-ColorOutput "✗ Policy assignment '$AssignmentName' not found" "Red"
            return $false
        }
    } catch {
        Write-ColorOutput "✗ Error checking policy assignment '$AssignmentName': $($_.Exception.Message)" "Red"
        return $false
    }
}

# Function to validate action group
function Test-ActionGroup {
    param(
        [string]$ActionGroupName,
        [string]$ResourceGroup
    )
    
    try {
        $actionGroup = Get-AzActionGroup -ResourceGroupName $ResourceGroup -Name $ActionGroupName -ErrorAction SilentlyContinue
        if ($actionGroup) {
            Write-ColorOutput "✓ Action group '$ActionGroupName' exists" "Green"
            Write-ColorOutput "  Short name: $($actionGroup.ShortName)" "Gray"
            Write-ColorOutput "  Email receivers: $($actionGroup.EmailReceivers.Count)" "Gray"
            return $true
        } else {
            Write-ColorOutput "✗ Action group '$ActionGroupName' not found" "Red"
            return $false
        }
    } catch {
        Write-ColorOutput "✗ Error checking action group '$ActionGroupName': $($_.Exception.Message)" "Red"
        return $false
    }
}

# Function to validate alert rule
function Test-AlertRule {
    param(
        [string]$AlertRuleName,
        [string]$ResourceGroup
    )
    
    try {
        $alertRule = Get-AzScheduledQueryRule -ResourceGroupName $ResourceGroup -Name $AlertRuleName -ErrorAction SilentlyContinue
        if ($alertRule) {
            Write-ColorOutput "✓ Alert rule '$AlertRuleName' exists" "Green"
            Write-ColorOutput "  Enabled: $($alertRule.Enabled)" "Gray"
            Write-ColorOutput "  Evaluation frequency: $($alertRule.EvaluationFrequency)" "Gray"
            Write-ColorOutput "  Severity: $($alertRule.Severity)" "Gray"
            return $true
        } else {
            Write-ColorOutput "✗ Alert rule '$AlertRuleName' not found" "Red"
            return $false
        }
    } catch {
        Write-ColorOutput "✗ Error checking alert rule '$AlertRuleName': $($_.Exception.Message)" "Red"
        return $false
    }
}

# Main validation logic
Write-ColorOutput "Starting validation for Azure Policy Expiry Monitoring..." "Blue"

# Connect to Azure
Write-ColorOutput "Connecting to Azure..." "Yellow"
Connect-AzAccount -SubscriptionId $SubscriptionId

# Set subscription context
Set-AzContext -SubscriptionId $SubscriptionId

$subscriptionScope = "/subscriptions/$SubscriptionId"
$validationResults = @()

# Validate policy definitions
Write-ColorOutput "`nValidating policy definitions..." "Yellow"
$validationResults += Test-PolicyDefinition -PolicyName "audit-expiring-resources"
$validationResults += Test-PolicyDefinition -PolicyName "audit-expiring-app-secrets"

# Validate policy assignments
Write-ColorOutput "`nValidating policy assignments..." "Yellow"
$validationResults += Test-PolicyAssignment -AssignmentName "audit-expiring-resources-assignment" -Scope $subscriptionScope
$validationResults += Test-PolicyAssignment -AssignmentName "audit-expiring-app-secrets-assignment" -Scope $subscriptionScope

# Validate action group
Write-ColorOutput "`nValidating action group..." "Yellow"
$validationResults += Test-ActionGroup -ActionGroupName "expiry-alerts-action-group" -ResourceGroup $ResourceGroupName

# Validate alert rule
Write-ColorOutput "`nValidating alert rule..." "Yellow"
$validationResults += Test-AlertRule -AlertRuleName "expiring-resources-alert" -ResourceGroup $ResourceGroupName

# Summary
Write-ColorOutput "`n--- Validation Summary ---" "Blue"
$passedCount = ($validationResults | Where-Object { $_ -eq $true }).Count
$totalCount = $validationResults.Count

if ($passedCount -eq $totalCount) {
    Write-ColorOutput "✓ All validations passed ($passedCount/$totalCount)" "Green"
    Write-ColorOutput "The Azure Policy Expiry Monitoring solution is properly deployed." "Green"
} else {
    Write-ColorOutput "✗ Some validations failed ($passedCount/$totalCount)" "Red"
    Write-ColorOutput "Please check the failed components and redeploy if necessary." "Red"
}

# Additional recommendations
Write-ColorOutput "`n--- Next Steps ---" "Blue"
Write-ColorOutput "1. Wait 30 minutes for policies to take effect" "White"
Write-ColorOutput "2. Check policy compliance in Azure Portal > Policy > Compliance" "White"
Write-ColorOutput "3. Test alert notifications by creating a resource with expiring secrets" "White"
Write-ColorOutput "4. Monitor alert rule performance in Azure Monitor" "White"

# Policy compliance check
Write-ColorOutput "`nChecking policy compliance..." "Yellow"
try {
    $complianceStates = Get-AzPolicyState -Filter "PolicyDefinitionName eq 'audit-expiring-resources' or PolicyDefinitionName eq 'audit-expiring-app-secrets'" -Top 10
    if ($complianceStates) {
        Write-ColorOutput "Found $($complianceStates.Count) policy compliance records" "Green"
        $nonCompliantCount = ($complianceStates | Where-Object { $_.ComplianceState -eq "NonCompliant" }).Count
        if ($nonCompliantCount -gt 0) {
            Write-ColorOutput "⚠️  $nonCompliantCount resources are non-compliant (have expiring secrets/certificates)" "Yellow"
        } else {
            Write-ColorOutput "✓ All evaluated resources are compliant" "Green"
        }
    } else {
        Write-ColorOutput "No policy compliance data found yet. This is normal for new deployments." "Yellow"
    }
} catch {
    Write-ColorOutput "Could not retrieve policy compliance data: $($_.Exception.Message)" "Yellow"
}

Write-ColorOutput "`nValidation completed!" "Green"