# Install-GitHubRunnerEnvironment.ps1
# Main setup script for GitHub Runner with Windows Server 2025, IIS, and Oracle

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$GitHubOrg,
    
    [Parameter(Mandatory = $false)]
    [string]$GitHubRepo,
    
    [Parameter(Mandatory = $false)]
    [string]$GitHubToken,
    
    [Parameter(Mandatory = $false)]
    [string]$RunnerName = $env:COMPUTERNAME,
    
    [Parameter(Mandatory = $false)]
    [string]$OraclePassword = "Oracle123!",
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipWindowsFeatures,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipOracle,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipRunner,
    
    [Parameter(Mandatory = $false)]
    [string]$LogPath = "C:\Logs\GitHubRunnerSetup.log"
)

# Import utility functions
. "$PSScriptRoot\..\utilities\Write-Log.ps1"
. "$PSScriptRoot\..\utilities\Test-Prerequisites.ps1"

function Install-GitHubRunnerEnvironment {
    Write-Log "Starting GitHub Runner Environment Installation" -Level "Info"
    
    try {
        # Create log directory
        $LogDir = Split-Path $LogPath -Parent
        if (!(Test-Path $LogDir)) {
            New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
        }
        
        # Test prerequisites
        Write-Log "Testing prerequisites..." -Level "Info"
        Test-Prerequisites
        
        # Install Windows Features
        if (!$SkipWindowsFeatures) {
            Write-Log "Installing Windows Features..." -Level "Info"
            & "$PSScriptRoot\Install-WindowsFeatures.ps1"
        }
        
        # Install Oracle
        if (!$SkipOracle) {
            Write-Log "Installing Oracle Express Edition..." -Level "Info"
            & "$PSScriptRoot\Install-Oracle.ps1" -Password $OraclePassword
        }
        
        # Install GitHub Runner
        if (!$SkipRunner) {
            Write-Log "Installing GitHub Runner..." -Level "Info"
            & "$PSScriptRoot\Install-GitHubRunner.ps1" -Organization $GitHubOrg -Repository $GitHubRepo -Token $GitHubToken -Name $RunnerName
        }
        
        # Configure security and performance
        Write-Log "Configuring security and performance settings..." -Level "Info"
        & "$PSScriptRoot\Configure-Security.ps1"
        & "$PSScriptRoot\Configure-Performance.ps1"
        
        # Validate installation
        Write-Log "Validating installation..." -Level "Info"
        & "$PSScriptRoot\..\validation\Test-Environment.ps1"
        
        Write-Log "GitHub Runner Environment Installation completed successfully!" -Level "Success"
        Write-Log "Please reboot the server to complete the installation." -Level "Warning"
        
    }
    catch {
        Write-Log "Installation failed: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

# Execute main function
Install-GitHubRunnerEnvironment
