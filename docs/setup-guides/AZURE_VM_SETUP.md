# Azure VM Setup Guide

This guide walks you through setting up a Windows Server 2025 DataCenter virtual machine in Azure for use as a GitHub self-hosted runner with IIS, Oracle Database, and third-party application deployment capabilities.

## 📋 Prerequisites

- **Azure Subscription** with sufficient permissions to create resources
- **Azure CLI** or **Azure PowerShell** installed on your local machine
- **GitHub Repository** with Actions enabled
- **Basic understanding** of Azure, PowerShell, and Windows Server

### Required Azure Permissions

Your account needs the following permissions:

- `Virtual Machine Contributor`
- `Network Contributor`
- `Storage Account Contributor`
- `Resource Group Contributor`

## 🏗️ VM Specifications

### Recommended Configuration

| Component | Specification | Notes |
|-----------|---------------|-------|
| **OS** | Windows Server 2025 DataCenter | Latest version recommended |
| **VM Size** | Standard_D4s_v5 or larger | 4 vCPUs, 16GB RAM minimum |
| **Storage** | Premium SSD | 128GB minimum |
| **Network** | Standard VNet with Public IP | RDP access required |
| **Region** | Any Azure region | Choose closest to your location |

### Minimum Requirements

- **CPU**: 4 cores
- **RAM**: 16GB
- **Storage**: 128GB SSD
- **Network**: Public IP for remote access

## 🚀 Quick Setup (Azure CLI)

### 1. Create Resource Group

```bash
# Set variables
RESOURCE_GROUP="rg-github-runner-win2025"
LOCATION="East US"
VM_NAME="vm-github-runner"
ADMIN_USERNAME="azureuser"

# Create resource group
az group create --name $RESOURCE_GROUP --location "$LOCATION"
```

### 2. Create Virtual Machine

```bash
# Create the VM
az vm create \
  --resource-group $RESOURCE_GROUP \
  --name $VM_NAME \
  --image "MicrosoftWindowsServer:WindowsServer:2025-datacenter-azure-edition-core:latest" \
  --size "Standard_D4s_v5" \
  --admin-username $ADMIN_USERNAME \
  --admin-password "YourSecurePassword123!" \
  --public-ip-sku Standard \
  --storage-sku Premium_LRS \
  --os-disk-size-gb 128
```

### 3. Open Required Ports

```bash
# Open RDP port
az vm open-port --resource-group $RESOURCE_GROUP --name $VM_NAME --port 3389

# Open HTTP port (for IIS)
az vm open-port --resource-group $RESOURCE_GROUP --name $VM_NAME --port 80

# Open HTTPS port (for IIS)
az vm open-port --resource-group $RESOURCE_GROUP --name $VM_NAME --port 443

# Open Oracle port (optional, if external access needed)
az vm open-port --resource-group $RESOURCE_GROUP --name $VM_NAME --port 1521
```

## 🎛️ Detailed Setup (Azure Portal)

### Step 1: Create Resource Group

1. Log in to the [Azure Portal](https://portal.azure.com)
2. Click **"Create a resource"**
3. Search for **"Resource group"**
4. Fill in the details:
   - **Resource group name**: `rg-github-runner-win2025`
   - **Region**: Choose your preferred region
5. Click **"Review + create"** → **"Create"**

### Step 2: Create Virtual Machine

1. Navigate to your resource group
2. Click **"+ Create"** → **"Virtual machine"**

#### Basics Tab

- **Subscription**: Select your Azure subscription
- **Resource group**: `rg-github-runner-win2025`
- **Virtual machine name**: `vm-github-runner`
- **Region**: Same as resource group
- **Availability options**: No infrastructure redundancy required
- **Security type**: Standard
- **Image**: Windows Server 2025 Datacenter - x64 Gen2
- **Size**: Standard_D4s_v5 (4 vcpus, 16 GiB memory)

#### Administrator Account

- **Username**: `azureuser` (or your preference)
- **Password**: Create a strong password
- **Confirm password**: Re-enter password

#### Inbound Port Rules

- **Public inbound ports**: Allow selected ports
- **Select inbound ports**: RDP (3389)

#### Disks Tab

- **OS disk type**: Premium SSD
- **OS disk size**: 128 GiB
- **Delete with VM**: Yes
- **Encryption type**: Default

#### Networking Tab

- **Virtual network**: Create new or use existing
- **Subnet**: default (10.0.0.0/24)
- **Public IP**: Create new
- **NIC network security group**: Basic
- **Public inbound ports**: Allow selected ports
- **Select inbound ports**: RDP (3389)

#### Management Tab

- **Enable auto-shutdown**: Optional (recommended for cost savings)
- **Auto-shutdown time**: 11:00 PM (if enabled)
- **Time zone**: Your local time zone

#### Advanced Tab

- Leave default settings

#### Tags Tab (Optional)

Add tags for organization:

- **Environment**: Development/Production
- **Purpose**: GitHub Runner
- **Owner**: Your name/team

### Step 3: Review and Create

1. Click **"Review + create"**
2. Review all settings
3. Click **"Create"**
4. Wait for deployment to complete (5-10 minutes)

## 🔐 Initial VM Configuration

### 1. Connect to the VM

1. Go to your VM in the Azure Portal
2. Click **"Connect"** → **"RDP"**
3. Download the RDP file
4. Open the RDP file and connect using your credentials

### 2. Configure Windows Updates

```powershell
# Run Windows Update
Install-WindowsUpdate -AcceptAll -AutoReboot
```

### 3. Enable Enhanced Session Mode

```powershell
# Enable Enhanced Session Mode for better RDP experience
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp" -Name "fEnableWinStation" -Value 1
```

### 4. Configure PowerShell Execution Policy

```powershell
# Set execution policy to allow script execution
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force
```

## 🛡️ Security Configuration

### 1. Windows Defender Configuration

```powershell
# Configure Windows Defender exclusions for development
Add-MpPreference -ExclusionPath "C:\Temp"
Add-MpPreference -ExclusionPath "C:\Logs"
Add-MpPreference -ExclusionPath "C:\actions-runner"
```

### 2. Windows Firewall Configuration

The setup scripts will automatically configure firewall rules. For manual configuration:

```powershell
# Allow IIS HTTP traffic
New-NetFirewallRule -DisplayName "Allow HTTP" -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow

# Allow IIS HTTPS traffic
New-NetFirewallRule -DisplayName "Allow HTTPS" -Direction Inbound -Protocol TCP -LocalPort 443 -Action Allow

# Allow Oracle (optional, for external connections)
New-NetFirewallRule -DisplayName "Allow Oracle" -Direction Inbound -Protocol TCP -LocalPort 1521 -Action Allow
```

### 3. Network Security Group Rules

Update the NSG to allow additional ports if needed:

```bash
# Add HTTP rule
az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name "${VM_NAME}NSG" \
  --name "Allow-HTTP" \
  --protocol tcp \
  --priority 1010 \
  --destination-port-range 80 \
  --access allow

# Add HTTPS rule
az network nsg rule create \
  --resource-group $RESOURCE_GROUP \
  --nsg-name "${VM_NAME}NSG" \
  --name "Allow-HTTPS" \
  --protocol tcp \
  --priority 1020 \
  --destination-port-range 443 \
  --access allow
```

## 📦 Install Required Software

### 1. Install Git

```powershell
# Download and install Git
$GitUrl = "https://github.com/git-for-windows/git/releases/latest/download/Git-2.43.0-64-bit.exe"
$GitInstaller = "C:\Temp\Git-installer.exe"
Invoke-WebRequest -Uri $GitUrl -OutFile $GitInstaller
Start-Process -FilePath $GitInstaller -ArgumentList "/SILENT" -Wait
```

### 2. Install Azure PowerShell

```powershell
# Install Azure PowerShell module
Install-Module -Name Az -AllowClobber -Scope AllUsers -Force
```

### 3. Install GitHub CLI (Optional)

```powershell
# Install GitHub CLI using winget
winget install --id GitHub.cli
```

## 🔧 Download and Run Setup Scripts

### 1. Clone the Repository

```powershell
# Create working directory
New-Item -Path "C:\Setup" -ItemType Directory -Force
Set-Location "C:\Setup"

# Clone the repository
git clone https://github.com/your-org/gh-runner-win-oracle-app-deploy-test.git
Set-Location "gh-runner-win-oracle-app-deploy-test"
```

### 2. Run the Main Setup Script

```powershell
# Run the main installation script
.\scripts\setup\Install-GitHubRunnerEnvironment.ps1 `
  -GitHubOrg "your-organization" `
  -GitHubRepo "your-repository" `
  -GitHubToken "your-github-token" `
  -RunnerName "azure-runner-01" `
  -OraclePassword "YourOraclePassword123!"
```

### 3. Verify Installation

```powershell
# Run validation tests
.\scripts\validation\Test-Environment.ps1
.\scripts\validation\Test-Applications.ps1
```

## 💰 Cost Optimization Setup

### Configure Automated Cleanup

To minimize Azure costs, set up automated daily resource group deletion:

```powershell
# Navigate to cleanup scripts
Set-Location "scripts\cleanup"

# Configure environment variables
$env:AZURE_RESOURCE_GROUP_NAME = "rg-github-runner-win2025"
$env:AZURE_SUBSCRIPTION_ID = "your-subscription-id"

# Test the cleanup script first
.\Remove-AzureResourceGroup.ps1 -DryRun

# Set up scheduled cleanup (runs daily at 11:00 PM)
.\Setup-ScheduledCleanup.ps1

# Verify the scheduled task
.\Manage-CleanupTask.ps1 -Action Status
```

⚠️ **IMPORTANT**: The cleanup script will delete the entire resource group daily at 11:00 PM. Make sure you understand this before enabling!

## 🔍 Troubleshooting

### Common Issues

#### 1. VM Creation Fails

**Problem**: Insufficient quota or permissions

**Solution**:

- Check your Azure subscription quotas
- Ensure you have the required permissions
- Try a different VM size or region

#### 2. RDP Connection Issues

**Problem**: Cannot connect via RDP

**Solution**:

```powershell
# Check if RDP is enabled
Get-Service -Name "TermService"

# Enable RDP if disabled
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 0
Enable-NetFirewallRule -DisplayGroup "Remote Desktop"
```

#### 3. Slow Performance

**Problem**: VM is running slowly

**Solution**:

- Upgrade to a larger VM size
- Use Premium SSD storage
- Check Windows Update status
- Monitor CPU and memory usage

#### 4. Network Connectivity Issues

**Problem**: Cannot access external resources

**Solution**:

- Check Network Security Group rules
- Verify public IP configuration
- Test DNS resolution
- Check Windows Firewall settings

### Performance Optimization

```powershell
# Disable unnecessary services
Set-Service -Name "Fax" -StartupType Disabled -Status Stopped
Set-Service -Name "XblAuthManager" -StartupType Disabled -Status Stopped
Set-Service -Name "XblGameSave" -StartupType Disabled -Status Stopped

# Configure virtual memory
$ComputerSystem = Get-WmiObject -Class Win32_ComputerSystem
$PageFileSize = [Math]::Floor($ComputerSystem.TotalPhysicalMemory / 1GB) * 1024
wmic computersystem where name="%computername%" set AutomaticManagedPagefile=False
wmic pagefileset where name="C:\\pagefile.sys" set InitialSize=$PageFileSize,MaximumSize=$PageFileSize
```

## 📚 Next Steps

After completing the Azure VM setup:

1. **[GitHub Runner Setup](GITHUB_RUNNER_SETUP.md)** - Configure the GitHub self-hosted runner
2. **[Oracle Database Setup](ORACLE_SETUP.md)** - Install and configure Oracle Express Edition
3. **[Application Deployment](APPLICATION_DEPLOYMENT.md)** - Deploy third-party applications
4. **[Complete Setup Guide](COMPLETE_SETUP_GUIDE.md)** - Full end-to-end setup instructions

## 📞 Support

For issues with this setup:

1. Check the [Troubleshooting Guide](../troubleshooting/COMMON_ISSUES.md)
2. Review the [main README](../../README.md)
3. Check Azure documentation for VM-specific issues
4. Create an issue in the GitHub repository

## 🔗 Useful Links

- [Azure Virtual Machines Documentation](https://docs.microsoft.com/en-us/azure/virtual-machines/)
- [Windows Server 2025 Documentation](https://docs.microsoft.com/en-us/windows-server/)
- [Azure CLI Reference](https://docs.microsoft.com/en-us/cli/azure/)
- [Azure PowerShell Documentation](https://docs.microsoft.com/en-us/powershell/azure/)
