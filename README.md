# Azure Policy Expiry Monitoring Solution

This solution provides comprehensive monitoring for expiring resources in Azure, including Key Vault secrets, certificates, Azure AD application secrets, and storage account keys. The solution uses Azure Policy to identify expiring resources and Azure Monitor to send alerts.

## Features

- **Multi-resource monitoring**: Monitors Key Vault secrets, certificates, Azure AD application secrets, and storage account keys
- **Configurable expiry threshold**: Set custom number of days before expiry to trigger alerts
- **Automated alerting**: Sends email notifications when expiring resources are detected
- **Policy-based compliance**: Uses Azure Policy for continuous compliance monitoring
- **Easy deployment**: PowerShell and Bash scripts for automated deployment

## Components

### Policy Definitions

1. **azure-policy-expiry-check.json**
   - Monitors Key Vault secrets, certificates, and storage account keys
   - Configurable expiry threshold (default: 30 days)
   - Audit effect for compliance tracking

2. **azure-policy-app-secrets-expiry.json**
   - Monitors Azure AD application secrets and certificates
   - Configurable expiry threshold (default: 30 days)
   - Audit effect for compliance tracking

### Templates

1. **policy-assignment-template.json**
   - ARM template for policy assignments
   - Parameterized for flexible deployment

2. **alert-rule-template.json**
   - ARM template for alert rule creation
   - Configurable evaluation frequency and window size

### Deployment Scripts

1. **deploy-policies.ps1**
   - PowerShell script for Windows/PowerShell environments
   - Comprehensive deployment with error handling

2. **deploy-policies.sh**
   - Bash script for Linux/macOS environments
   - Full feature parity with PowerShell version

## Prerequisites

- Azure CLI or Azure PowerShell installed
- Appropriate permissions in Azure:
  - Policy Contributor role (minimum)
  - Resource Group Contributor role
  - User Access Administrator role (for resource assignments)

## Quick Start

### Using PowerShell (Windows)

```powershell
# Basic deployment
.\deploy-policies.ps1 -SubscriptionId "your-subscription-id" -ResourceGroupName "your-rg-name"

# With email notifications
.\deploy-policies.ps1 -SubscriptionId "your-subscription-id" -ResourceGroupName "your-rg-name" -NotificationEmail "admin@company.com"

# Custom configuration
.\deploy-policies.ps1 -SubscriptionId "your-subscription-id" -ResourceGroupName "your-rg-name" -DaysBeforeExpiry 14 -Location "West US 2"
```

### Using Bash (Linux/macOS)

```bash
# Basic deployment
./deploy-policies.sh -s "your-subscription-id" -g "your-rg-name"

# With email notifications
./deploy-policies.sh -s "your-subscription-id" -g "your-rg-name" -e "admin@company.com"

# Custom configuration
./deploy-policies.sh -s "your-subscription-id" -g "your-rg-name" -d 14 -l "westus2"
```

## Parameters

| Parameter | Description | Default | Required |
|-----------|-------------|---------|----------|
| SubscriptionId | Azure subscription ID | - | Yes |
| ResourceGroupName | Resource group for alerts | - | Yes |
| Location | Azure region | East US / eastus | No |
| DaysBeforeExpiry | Days before expiry to alert | 30 | No |
| NotificationEmail | Email for notifications | - | No |

## Monitoring Resources

The solution monitors the following resource types:

### Key Vault Resources
- **Secrets**: Monitors `expires` attribute
- **Certificates**: Monitors `expires` attribute
- **Keys**: Monitors `expires` attribute (if configured)

### Azure AD Applications
- **Password Credentials**: Monitors `endDateTime` attribute
- **Key Credentials**: Monitors `endDateTime` attribute (certificates)

### Storage Accounts
- **Access Keys**: Monitors based on `keyCreationTime` + 90 days
- **SAS Tokens**: Monitors `signedExpiry` attribute

## Alert Configuration

### Default Settings
- **Evaluation Frequency**: Daily (P1D)
- **Window Size**: 1 Day (P1D)
- **Severity**: Warning (Level 2)
- **Threshold**: Any non-compliant resource

### Customization
You can modify the alert rule template to change:
- Evaluation frequency (hourly, daily, weekly)
- Alert severity
- Query logic
- Action groups

## Policy Compliance

### Viewing Compliance
1. Navigate to Azure Portal > Policy
2. Select "Compliance" from the left menu
3. Look for the expiry monitoring policies:
   - "Audit resources with expiring secrets and certificates"
   - "Audit Azure AD Applications with expiring secrets and certificates"

### Understanding Results
- **Compliant**: Resources are not expiring within the threshold
- **Non-compliant**: Resources are expiring within the threshold
- **Not applicable**: Resources don't have expiry dates set

## Troubleshooting

### Common Issues

1. **Policy assignment not working**
   - Wait 30 minutes for policies to take effect
   - Check if you have sufficient permissions
   - Verify the policy definition was created correctly

2. **No alerts being received**
   - Verify the action group is configured correctly
   - Check if there are actually non-compliant resources
   - Review the alert rule query in Log Analytics

3. **Permissions errors**
   - Ensure you have Policy Contributor role
   - Check resource group permissions
   - Verify subscription-level access

### Log Analysis

Query to check policy compliance:
```kusto
PolicyInsights
| where PolicyDefinitionName contains "expiring"
| where ComplianceState == "NonCompliant"
| project TimeGenerated, ResourceId, ResourceType, ComplianceState
| order by TimeGenerated desc
```

## Customization

### Modifying Expiry Threshold
Edit the policy parameters in the deployment scripts:
```json
{
  "daysBeforeExpiry": {
    "value": 14  // Change to desired number of days
  }
}
```

### Adding New Resource Types
1. Modify the policy definition JSON files
2. Add new `allOf` blocks for additional resource types
3. Update the field references for the new resources

### Custom Alert Actions
1. Create additional action groups (SMS, webhooks, etc.)
2. Modify the alert rule template
3. Add new action groups to the `actions` array

## Best Practices

1. **Set appropriate thresholds**: Consider certificate renewal processes
2. **Test notifications**: Verify alert delivery before production
3. **Regular reviews**: Periodically review and update policies
4. **Document exceptions**: Use policy exemptions for known cases
5. **Monitor performance**: Check policy evaluation performance

## Security Considerations

- Policies only audit resources; they don't modify them
- Alert emails may contain resource identifiers
- Consider using managed identities for automated responses
- Restrict access to action groups and alert rules

## Contributing

To contribute to this solution:
1. Fork the repository
2. Create a feature branch
3. Test your changes thoroughly
4. Submit a pull request

## License

This solution is provided as-is for educational and production use. Please review and test thoroughly before deploying in production environments.

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review Azure Policy documentation
3. Open an issue in the repository
4. Contact your Azure support team for production issues