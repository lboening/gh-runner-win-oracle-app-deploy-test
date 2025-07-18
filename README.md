# GitHub Runner Windows Oracle Application Deployment

This repository provides comprehensive automation scripts and templates for setting up Windows Server 2025 DataCenter in Azure as a GitHub self-hosted runner with IIS, Oracle Database, and third-party application deployment capabilities.

## 🚀 Quick Start

1. **Prerequisites**
   - Azure subscription with appropriate permissions
   - Windows Server 2025 DataCenter VM in Azure
   - PowerShell 5.1 or later
   - GitHub repository with Actions enabled

2. **Initial Setup**

   ```powershell
   # Clone this repository
   git clone https://github.com/your-org/gh-runner-win-oracle-app-deploy-test.git
   cd gh-runner-win-oracle-app-deploy-test
   
   # Run the main setup script
   .\scripts\setup\Install-GitHubRunnerEnvironment.ps1
   ```

## 📁 Project Structure

- **`scripts/`** - PowerShell automation scripts
  - `setup/` - Server setup and configuration
  - `deployment/` - Application deployment automation
  - `validation/` - Testing and validation scripts
  - `utilities/` - Helper functions and utilities
  - `cleanup/` - Automated Azure resource cleanup for cost optimization
- **`configs/`** - Configuration files for IIS, Oracle, and applications
- **`templates/`** - GitHub Actions workflows and Azure ARM templates
- **`docs/`** - Comprehensive documentation and guides
- **`tests/`** - Unit and integration tests
- **`examples/`** - Example configurations and use cases

## 🛠️ Features

- ✅ Automated Windows Server 2025 setup
- ✅ GitHub self-hosted runner installation
- ✅ IIS configuration with application pools
- ✅ Oracle Express Edition setup
- ✅ Third-party application deployment from Azure Blob Storage
- ✅ Security hardening and performance optimization
- ✅ Comprehensive logging and monitoring
- ✅ Automated testing and validation
- ✅ **Automated daily resource cleanup for cost optimization**

## 📖 Documentation

- [Complete Setup Guide](docs/setup-guides/COMPLETE_SETUP_GUIDE.md)
- [Azure VM Configuration](docs/setup-guides/AZURE_VM_SETUP.md)
- [GitHub Runner Setup](docs/setup-guides/GITHUB_RUNNER_SETUP.md)
- [Oracle Database Setup](docs/setup-guides/ORACLE_SETUP.md)
- [Application Deployment](docs/setup-guides/APPLICATION_DEPLOYMENT.md)
- [Troubleshooting Guide](docs/troubleshooting/COMMON_ISSUES.md)

## 🔧 Configuration

See the `configs/` directory for example configurations:

- IIS website and application pool settings
- Oracle database connection strings
- Application deployment parameters

## 💰 Cost Optimization

This project includes automated cleanup scripts that run daily at 23:00 to delete the entire Azure resource group, helping to minimize costs when the environment is not in use.

**⚠️ IMPORTANT**: The cleanup scripts will permanently delete all resources in the specified resource group!

### Quick Setup for Daily Cleanup

```powershell
# Configure your Azure details (run as Administrator)
cd scripts\cleanup
.\Setup-ScheduledCleanup.ps1 -ResourceGroupName "your-rg-name" -SubscriptionId "your-subscription-id"

# Test first with dry run
.\Remove-AzureResourceGroup.ps1 -ResourceGroupName "your-rg-name" -SubscriptionId "your-subscription-id" -DryRun

# Check scheduled task status
.\Manage-CleanupTask.ps1 -Action Status
```

For detailed cleanup documentation, see [`scripts/cleanup/README.md`](scripts/cleanup/README.md).

## 🧪 Testing

Run the validation scripts to ensure proper setup:

```powershell
.\scripts\validation\Test-Environment.ps1
.\scripts\validation\Test-Applications.ps1
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.
