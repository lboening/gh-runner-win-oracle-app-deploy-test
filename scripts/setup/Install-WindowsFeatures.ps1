# Install-WindowsFeatures.ps1
# Installs required Windows Features for IIS and application support

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$LogPath = "C:\Logs\WindowsFeatures.log"
)

# Import logging utility
. "$PSScriptRoot\..\utilities\Write-Log.ps1"

function Install-RequiredWindowsFeatures {
    Write-Log "Starting Windows Features installation..." -Level "Info"
    
    $Features = @(
        # IIS Core Features
        "IIS-WebServerRole",
        "IIS-WebServer",
        "IIS-CommonHttpFeatures",
        "IIS-HttpErrors",
        "IIS-HttpRedirect",
        "IIS-ApplicationDevelopment",
        
        # .NET Framework Support
        "IIS-NetFx45",
        "IIS-NetFxExtensibility45",
        "IIS-ASPNET45",
        "IIS-NetFx4Extended-ASPNET45",
        
        # ISAPI Extensions
        "IIS-ISAPIExtensions",
        "IIS-ISAPIFilter",
        
        # Management Tools
        "IIS-ManagementConsole",
        "IIS-IIS6ManagementCompatibility",
        "IIS-Metabase",
        
        # Authentication
        "IIS-BasicAuthentication",
        "IIS-WindowsAuthentication",
        
        # Additional .NET Features
        "NetFx4-AdvSrvs",
        "NetFx4Extended-ASPNET45",
        
        # WCF Services
        "WCF-Services45",
        "WCF-HTTP-Activation45",
        "WCF-TCP-Activation45"
    )
    
    $FailedFeatures = @()
    $SuccessfulFeatures = @()
    
    foreach ($Feature in $Features) {
        try {
            Write-Log "Installing feature: $Feature" -Level "Info"
            $Result = Enable-WindowsOptionalFeature -Online -FeatureName $Feature -All -NoRestart
            
            if ($Result.RestartNeeded) {
                Write-Log "Feature $Feature installed successfully (restart required)" -Level "Warning"
            }
            else {
                Write-Log "Feature $Feature installed successfully" -Level "Success"
            }
            
            $SuccessfulFeatures += $Feature
        }
        catch {
            Write-Log "Failed to install feature $Feature`: $($_.Exception.Message)" -Level "Error"
            $FailedFeatures += $Feature
        }
    }
    
    # Summary
    Write-Log "Windows Features Installation Summary:" -Level "Info"
    Write-Log "Successful: $($SuccessfulFeatures.Count)" -Level "Success"
    Write-Log "Failed: $($FailedFeatures.Count)" -Level "Error"
    
    if ($FailedFeatures.Count -gt 0) {
        Write-Log "Failed features: $($FailedFeatures -join ', ')" -Level "Error"
        throw "Some Windows features failed to install"
    }
    
    Write-Log "All Windows features installed successfully!" -Level "Success"
}

# Execute main function
Install-RequiredWindowsFeatures
