# GitHub CLI Azure Authorization Setup Guide

## Overview

This guide explains how to use GitHub CLI (gh) to create and manage the necessary GitHub repository secrets for Azure authentication. These secrets are required for the Azure Authorization Checks workflow and other Azure-related operations.

## Prerequisites

### Required Tools

1. **GitHub CLI (gh)**
   - Version 2.0 or later
   - Installation: [GitHub CLI Installation Guide](https://cli.github.com/)

2. **Azure CLI (az)**
   - Version 2.50 or later
   - Installation: [Azure CLI Installation Guide](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)

3. **PowerShell** (Windows) or **Bash** (Linux/macOS)

### Required Permissions

- **Azure**: Contributor or Owner role on the target subscription
- **GitHub**: Admin access to the repository to manage secrets

## Step 1: Install and Setup GitHub CLI

### Windows (PowerShell)

```powershell
# Install via winget
winget install --id GitHub.cli

# Or via Chocolatey
choco install gh

# Or via Scoop
scoop install gh
```

### Linux/macOS

```bash
# Ubuntu/Debian
sudo apt install gh

# macOS via Homebrew
brew install gh

# CentOS/RHEL/Fedora
sudo dnf install gh
```

### Verify Installation

```bash
gh --version
```

## Step 2: Authenticate with GitHub

### Login to GitHub

```bash
# Interactive login (opens web browser)
gh auth login

# Or login with token
gh auth login --with-token < your-token.txt
```

### Verify Authentication

```bash
# Check current authentication status
gh auth status

# List available repositories
gh repo list
```

## Step 3: Setup Azure Service Principal

### Create Azure Service Principal

```bash
# Login to Azure
az login

# Set your subscription (replace with your subscription ID)
az account set --subscription "your-subscription-id"

# Create service principal with Contributor role
az ad sp create-for-rbac \
  --name "gh-runner-sp-$(date +%Y%m%d)" \
  --role "Contributor" \
  --scopes "/subscriptions/your-subscription-id" \
  --sdk-auth
```

### Expected Output

```json
{
  "clientId": "12345678-1234-1234-1234-123456789012",
  "clientSecret": "your-client-secret-here",
  "subscriptionId": "87654321-4321-4321-4321-210987654321",
  "tenantId": "11111111-2222-3333-4444-555555555555",
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  "resourceManagerEndpointUrl": "https://management.azure.com/",
  "activeDirectoryGraphResourceId": "https://graph.windows.net/",
  "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
  "galleryEndpointUrl": "https://gallery.azure.com/",
  "managementEndpointUrl": "https://management.core.windows.net/"
}
```

### Extract Required Values

From the JSON output, extract these values:
- `clientId` → `AZURE_CLIENT_ID`
- `clientSecret` → `AZURE_CLIENT_SECRET`
- `subscriptionId` → `AZURE_SUBSCRIPTION_ID`
- `tenantId` → `AZURE_TENANT_ID`

## Step 4: Create GitHub Repository Secrets

### Using GitHub CLI Commands

Navigate to your repository directory and run these commands:

```bash
# Navigate to your repository
cd /path/to/your/repository

# Create Azure Client ID secret
gh secret set AZURE_CLIENT_ID --body "12345678-1234-1234-1234-123456789012"

# Create Azure Client Secret secret
gh secret set AZURE_CLIENT_SECRET --body "your-client-secret-here"

# Create Azure Subscription ID secret
gh secret set AZURE_SUBSCRIPTION_ID --body "87654321-4321-4321-4321-210987654321"

# Create Azure Tenant ID secret
gh secret set AZURE_TENANT_ID --body "11111111-2222-3333-4444-555555555555"
```

### Alternative: Using Environment Variables

```bash
# Set environment variables
export AZURE_CLIENT_ID="12345678-1234-1234-1234-123456789012"
export AZURE_CLIENT_SECRET="your-client-secret-here"
export AZURE_SUBSCRIPTION_ID="87654321-4321-4321-4321-210987654321"
export AZURE_TENANT_ID="11111111-2222-3333-4444-555555555555"

# Create secrets from environment variables
gh secret set AZURE_CLIENT_ID --body "$AZURE_CLIENT_ID"
gh secret set AZURE_CLIENT_SECRET --body "$AZURE_CLIENT_SECRET"
gh secret set AZURE_SUBSCRIPTION_ID --body "$AZURE_SUBSCRIPTION_ID"
gh secret set AZURE_TENANT_ID --body "$AZURE_TENANT_ID"
```

### Using Files for Secure Input

```bash
# Create temporary files with values
echo "12345678-1234-1234-1234-123456789012" > azure_client_id.txt
echo "your-client-secret-here" > azure_client_secret.txt
echo "87654321-4321-4321-4321-210987654321" > azure_subscription_id.txt
echo "11111111-2222-3333-4444-555555555555" > azure_tenant_id.txt

# Create secrets from files
gh secret set AZURE_CLIENT_ID < azure_client_id.txt
gh secret set AZURE_CLIENT_SECRET < azure_client_secret.txt
gh secret set AZURE_SUBSCRIPTION_ID < azure_subscription_id.txt
gh secret set AZURE_TENANT_ID < azure_tenant_id.txt

# Clean up temporary files
rm azure_*.txt
```

## Step 5: Verify Secret Creation

### List Repository Secrets

```bash
# List all secrets in the repository
gh secret list

# Expected output:
# AZURE_CLIENT_ID        Updated 2025-07-19T10:30:00Z
# AZURE_CLIENT_SECRET    Updated 2025-07-19T10:30:00Z
# AZURE_SUBSCRIPTION_ID  Updated 2025-07-19T10:30:00Z
# AZURE_TENANT_ID        Updated 2025-07-19T10:30:00Z
```

### Test Secret Accessibility

```bash
# View secret metadata (values are hidden)
gh secret list --json name,created_at,updated_at

# Check if all required secrets exist
gh secret list | grep -E "(AZURE_CLIENT_ID|AZURE_CLIENT_SECRET|AZURE_SUBSCRIPTION_ID|AZURE_TENANT_ID)"
```

## Step 6: Test Azure Authorization

### Run Authorization Check Workflow

```bash
# Trigger the workflow manually
gh workflow run "Quality Checks" --ref main

# Monitor workflow status
gh run list --workflow="Quality Checks"

# View specific run details
gh run view --log
```

### Verify Azure Access (Local Test)

```bash
# Test Azure login with service principal
az login --service-principal \
  --username "$AZURE_CLIENT_ID" \
  --password "$AZURE_CLIENT_SECRET" \
  --tenant "$AZURE_TENANT_ID"

# Test subscription access
az account set --subscription "$AZURE_SUBSCRIPTION_ID"

# List resource groups to verify permissions
az group list --output table
```

## Advanced Configuration

### Organization-Level Secrets

For multiple repositories, create organization-level secrets:

```bash
# Create organization secrets (requires org admin permissions)
gh secret set AZURE_CLIENT_ID --org your-org-name --body "value"
gh secret set AZURE_CLIENT_SECRET --org your-org-name --body "value"
gh secret set AZURE_SUBSCRIPTION_ID --org your-org-name --body "value"
gh secret set AZURE_TENANT_ID --org your-org-name --body "value"

# Set repository access for organization secrets
gh secret set AZURE_CLIENT_ID --org your-org-name --repos "repo1,repo2,repo3"
```

### Environment-Specific Secrets

For multiple environments (dev, staging, prod):

```bash
# Development environment
gh secret set AZURE_CLIENT_ID_DEV --body "dev-client-id"
gh secret set AZURE_CLIENT_SECRET_DEV --body "dev-client-secret"
gh secret set AZURE_SUBSCRIPTION_ID_DEV --body "dev-subscription-id"
gh secret set AZURE_TENANT_ID_DEV --body "dev-tenant-id"

# Production environment
gh secret set AZURE_CLIENT_ID_PROD --body "prod-client-id"
gh secret set AZURE_CLIENT_SECRET_PROD --body "prod-client-secret"
gh secret set AZURE_SUBSCRIPTION_ID_PROD --body "prod-subscription-id"
gh secret set AZURE_TENANT_ID_PROD --body "prod-tenant-id"
```

### Automated Setup Script

Create a PowerShell script for automated setup:

```powershell
# setup-azure-secrets.ps1
param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId,
    
    [Parameter(Mandatory=$true)]
    [string]$ServicePrincipalName = "gh-runner-sp-$(Get-Date -Format 'yyyyMMdd')"
)

# Login to Azure
Write-Host "Logging in to Azure..." -ForegroundColor Green
az login

# Set subscription
Write-Host "Setting subscription..." -ForegroundColor Green
az account set --subscription $SubscriptionId

# Create service principal
Write-Host "Creating service principal..." -ForegroundColor Green
$spOutput = az ad sp create-for-rbac `
    --name $ServicePrincipalName `
    --role "Contributor" `
    --scopes "/subscriptions/$SubscriptionId" `
    --sdk-auth | ConvertFrom-Json

# Create GitHub secrets
Write-Host "Creating GitHub secrets..." -ForegroundColor Green
gh secret set AZURE_CLIENT_ID --body $spOutput.clientId
gh secret set AZURE_CLIENT_SECRET --body $spOutput.clientSecret
gh secret set AZURE_SUBSCRIPTION_ID --body $spOutput.subscriptionId
gh secret set AZURE_TENANT_ID --body $spOutput.tenantId

Write-Host "✅ Azure authorization setup completed!" -ForegroundColor Green
Write-Host "Service Principal: $ServicePrincipalName" -ForegroundColor Yellow
```

## Security Best Practices

### 1. **Service Principal Permissions**

Use principle of least privilege:

```bash
# Create service principal with specific resource group scope
az ad sp create-for-rbac \
  --name "gh-runner-sp-limited" \
  --role "Contributor" \
  --scopes "/subscriptions/your-sub-id/resourceGroups/your-rg-name"

# Or with custom role
az ad sp create-for-rbac \
  --name "gh-runner-sp-custom" \
  --role "GitHub Runner Deployer" \
  --scopes "/subscriptions/your-sub-id"
```

### 2. **Secret Rotation**

Regularly rotate secrets:

```bash
# Generate new client secret for existing service principal
az ad sp credential reset --id "$AZURE_CLIENT_ID" --years 1

# Update GitHub secret with new value
gh secret set AZURE_CLIENT_SECRET --body "new-client-secret"
```

### 3. **Audit and Monitoring**

Monitor secret usage:

```bash
# Check when secrets were last used
gh secret list --json name,created_at,updated_at

# View workflow runs using secrets
gh run list --workflow="Quality Checks"
```

### 4. **Access Control**

Limit secret access:

```bash
# Use environment-specific secrets
gh secret set AZURE_CLIENT_ID_PROD --body "value" --env production
gh secret set AZURE_CLIENT_SECRET_PROD --body "value" --env production
```

## Troubleshooting

### Common Issues

#### 1. **Authentication Failures**

```bash
# Check GitHub CLI authentication
gh auth status

# Re-authenticate if needed
gh auth login --force
```

#### 2. **Azure Permission Issues**

```bash
# Check Azure login status
az account show

# Verify subscription access
az account list --output table

# Check service principal permissions
az role assignment list --assignee "$AZURE_CLIENT_ID" --output table
```

#### 3. **Secret Creation Failures**

```bash
# Check repository permissions
gh repo view --json permissions

# Verify you're in the correct repository
gh repo view
```

#### 4. **Service Principal Issues**

```bash
# List existing service principals
az ad sp list --display-name "gh-runner-sp*" --output table

# Check service principal credentials
az ad sp credential list --id "$AZURE_CLIENT_ID"
```

### Debugging Commands

```bash
# Enable verbose output
gh secret set AZURE_CLIENT_ID --body "value" --verbose

# Check API limits
gh api rate_limit

# View raw GitHub API responses
gh api repos/:owner/:repo/actions/secrets
```

### Recovery Procedures

#### Reset Service Principal

```bash
# If service principal is compromised
az ad sp credential reset --id "$AZURE_CLIENT_ID"
gh secret set AZURE_CLIENT_SECRET --body "new-secret"
```

#### Recreate All Secrets

```bash
# Delete existing secrets
gh secret delete AZURE_CLIENT_ID
gh secret delete AZURE_CLIENT_SECRET
gh secret delete AZURE_SUBSCRIPTION_ID
gh secret delete AZURE_TENANT_ID

# Recreate with new values
# (Follow Step 4 again)
```

## Verification Checklist

- [ ] GitHub CLI installed and authenticated
- [ ] Azure CLI installed and authenticated
- [ ] Service principal created with appropriate permissions
- [ ] All four Azure secrets created in GitHub repository
- [ ] Secrets accessible via `gh secret list`
- [ ] Azure Authorization Checks workflow runs successfully
- [ ] Local Azure authentication test passes

## Additional Resources

- [GitHub CLI Manual](https://cli.github.com/manual/)
- [GitHub Secrets Documentation](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Azure Service Principal Documentation](https://docs.microsoft.com/en-us/azure/active-directory/develop/app-objects-and-service-principals)
- [Azure CLI Reference](https://docs.microsoft.com/en-us/cli/azure/reference-index)
- [Azure RBAC Documentation](https://docs.microsoft.com/en-us/azure/role-based-access-control/)

## Support

If you encounter issues:

1. Check the [Troubleshooting](#troubleshooting) section above
2. Review GitHub Actions workflow logs
3. Verify Azure service principal permissions
4. Consult the Azure Authorization Checks job output in the Quality Checks workflow
