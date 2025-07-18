# Write-Log.ps1
# Utility function for consistent logging across all scripts

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Info", "Warning", "Error", "Success", "Debug")]
        [string]$Level = "Info",
        
        [Parameter(Mandatory = $false)]
        [string]$LogFile = "C:\Logs\GitHubRunner_$(Get-Date -Format 'yyyyMMdd').log"
    )
    
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$Timestamp] [$Level] $Message"
    
    # Ensure log directory exists
    $LogDir = Split-Path $LogFile -Parent
    if (!(Test-Path $LogDir)) {
        New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
    }
    
    # Console output with colors
    switch ($Level) {
        "Info" { Write-Host $LogMessage -ForegroundColor White }
        "Warning" { Write-Host $LogMessage -ForegroundColor Yellow }
        "Error" { Write-Host $LogMessage -ForegroundColor Red }
        "Success" { Write-Host $LogMessage -ForegroundColor Green }
        "Debug" { Write-Host $LogMessage -ForegroundColor Gray }
    }
    
    # File output
    try {
        $LogMessage | Out-File -FilePath $LogFile -Append -Encoding UTF8
    }
    catch {
        Write-Warning "Failed to write to log file: $($_.Exception.Message)"
    }
    
    # Windows Event Log
    try {
        if (![System.Diagnostics.EventLog]::SourceExists("GitHubRunner")) {
            New-EventLog -LogName "Application" -Source "GitHubRunner"
        }
        
        $EventType = switch ($Level) {
            "Error" { "Error" }
            "Warning" { "Warning" }
            default { "Information" }
        }
        
        Write-EventLog -LogName "Application" -Source "GitHubRunner" -EventId 1001 -EntryType $EventType -Message $Message
    }
    catch {
        # Silently ignore event log errors to prevent infinite loops
    }
}
