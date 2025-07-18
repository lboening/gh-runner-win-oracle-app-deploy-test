# Test-Applications.ps1
# Application validation script including Oracle integration tests

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$IncludeOracleIntegration,
    
    [Parameter(Mandatory = $false)]
    [switch]$QuickTest,
    
    [Parameter(Mandatory = $false)]
    [string]$LogPath = "C:\Logs\ApplicationValidation.log"
)

# Import utilities
. "$PSScriptRoot\..\utilities\Write-Log.ps1"

function Test-IISApplications {
    $Results = @{}
    
    try {
        # Check IIS service
        $IISService = Get-Service -Name "W3SVC" -ErrorAction Stop
        if ($IISService.Status -eq "Running") {
            $Results["IIS_Service"] = @{ Status = "Pass"; Message = "IIS service is running" }
        }
        else {
            $Results["IIS_Service"] = @{ Status = "Fail"; Message = "IIS service is not running" }
        }
        
        # Check for IIS sites
        if (Get-Module -ListAvailable -Name WebAdministration) {
            Import-Module WebAdministration -Force
            $Sites = Get-Website
            
            if ($Sites.Count -gt 0) {
                $RunningSites = $Sites | Where-Object { $_.State -eq "Started" }
                $Results["IIS_Sites"] = @{ 
                    Status = if ($RunningSites.Count -gt 0) { "Pass" } else { "Fail" }
                    Message = "$($RunningSites.Count) of $($Sites.Count) sites running" 
                }
            }
            else {
                $Results["IIS_Sites"] = @{ Status = "Warning"; Message = "No IIS sites configured" }
            }
        }
        else {
            $Results["IIS_Sites"] = @{ Status = "Warning"; Message = "WebAdministration module not available" }
        }
    }
    catch {
        $Results["IIS_Service"] = @{ Status = "Fail"; Message = "IIS service not found or error occurred" }
    }
    
    return $Results
}

function Test-OracleBasic {
    $Results = @{}
    
    # Basic Oracle service check
    try {
        $OracleService = Get-Service -Name "OracleServiceXE" -ErrorAction Stop
        if ($OracleService.Status -eq "Running") {
            $Results["Oracle_Service"] = @{ Status = "Pass"; Message = "Oracle service is running" }
        }
        else {
            $Results["Oracle_Service"] = @{ Status = "Fail"; Message = "Oracle service is not running" }
        }
    }
    catch {
        $Results["Oracle_Service"] = @{ Status = "Fail"; Message = "Oracle service not found" }
    }
    
    # TNS Listener check
    try {
        $ListenerService = Get-Service -Name "OracleXETNSListener" -ErrorAction SilentlyContinue
        if ($ListenerService) {
            if ($ListenerService.Status -eq "Running") {
                $Results["Oracle_Listener"] = @{ Status = "Pass"; Message = "Oracle listener is running" }
            }
            else {
                $Results["Oracle_Listener"] = @{ Status = "Fail"; Message = "Oracle listener is not running" }
            }
        }
        else {
            $Results["Oracle_Listener"] = @{ Status = "Warning"; Message = "Oracle listener service not found" }
        }
    }
    catch {
        $Results["Oracle_Listener"] = @{ Status = "Fail"; Message = "Error checking Oracle listener" }
    }
    
    return $Results
}

function Invoke-OracleIntegrationTests {
    try {
        Write-Log "Running Oracle integration tests..." -Level "Info"
        
        $IntegrationTestPath = "$PSScriptRoot\..\..\tests\integration\Test-OracleIntegration.ps1"
        
        if (!(Test-Path $IntegrationTestPath)) {
            Write-Log "Oracle integration test not found: $IntegrationTestPath" -Level "Warning"
            return @{ Status = "Warning"; Message = "Integration tests not available" }
        }
        
        # Execute the integration test
        $ProcessStartInfo = New-Object System.Diagnostics.ProcessStartInfo
        $ProcessStartInfo.FileName = "PowerShell.exe"
        $ProcessStartInfo.Arguments = "-ExecutionPolicy Bypass -File `"$IntegrationTestPath`" -ContinueOnFailure"
        $ProcessStartInfo.RedirectStandardOutput = $true
        $ProcessStartInfo.RedirectStandardError = $true
        $ProcessStartInfo.UseShellExecute = $false
        $ProcessStartInfo.CreateNoWindow = $true
        
        $Process = New-Object System.Diagnostics.Process
        $Process.StartInfo = $ProcessStartInfo
        
        $Process.Start() | Out-Null
        $Process.WaitForExit(120000)  # 2 minutes timeout
        
        if (!$Process.HasExited) {
            $Process.Kill()
            return @{ Status = "Fail"; Message = "Integration tests timed out" }
        }
        
        $ExitCode = $Process.ExitCode
        $Output = $Process.StandardOutput.ReadToEnd()
        
        if ($ExitCode -eq 0) {
            return @{ Status = "Pass"; Message = "Oracle integration tests passed" }
        }
        else {
            return @{ Status = "Fail"; Message = "Oracle integration tests failed (exit code: $ExitCode)" }
        }
    }
    catch {
        return @{ Status = "Fail"; Message = "Error running integration tests: $($_.Exception.Message)" }
    }
}

function Test-Applications {
    Write-Log "Starting application validation..." -Level "Info"
    
    $ValidationResults = @{
        IISApplications = Test-IISApplications
        OracleBasic = Test-OracleBasic
    }
    
    # Add Oracle integration tests if requested
    if ($IncludeOracleIntegration) {
        Write-Log "Including Oracle integration tests..." -Level "Info"
        $OracleIntegrationResult = Invoke-OracleIntegrationTests
        $ValidationResults["OracleIntegration"] = @{ "Integration_Tests" = $OracleIntegrationResult }
    }
    
    # Generate summary report
    $TotalTests = 0
    $PassedTests = 0
    
    foreach ($Category in $ValidationResults.Keys) {
        $CategoryResults = $ValidationResults[$Category]
        Write-Log "=== $Category Validation ===" -Level "Info"
        
        foreach ($Test in $CategoryResults.Keys) {
            $TotalTests++
            $Result = $CategoryResults[$Test]
            
            switch ($Result.Status) {
                "Pass" {
                    $PassedTests++
                    Write-Log "✓ $Test`: $($Result.Message)" -Level "Success"
                }
                "Warning" {
                    Write-Log "⚠ $Test`: $($Result.Message)" -Level "Warning"
                }
                "Fail" {
                    Write-Log "✗ $Test`: $($Result.Message)" -Level "Error"
                }
            }
        }
        Write-Log "" -Level "Info"
    }
    
    # Overall summary
    $SuccessRate = if ($TotalTests -gt 0) { [math]::Round(($PassedTests / $TotalTests) * 100, 1) } else { 0 }
    Write-Log "=== Application Validation Summary ===" -Level "Info"
    Write-Log "Total Tests: $TotalTests" -Level "Info"
    Write-Log "Passed Tests: $PassedTests" -Level "Success"
    Write-Log "Success Rate: $SuccessRate%" -Level "Info"
    
    if ($SuccessRate -eq 100) {
        Write-Log "All application tests passed!" -Level "Success"
        return $true
    }
    elseif ($SuccessRate -ge 75) {
        Write-Log "Most application tests passed" -Level "Warning"
        return $true
    }
    else {
        Write-Log "Many application tests failed" -Level "Error"
        return $false
    }
}

# Main execution
try {
    Write-Log "=== Application Validation Started ===" -Level "Info"
    Write-Log "Timestamp: $(Get-Date)" -Level "Info"
    Write-Log "Include Oracle Integration: $IncludeOracleIntegration" -Level "Info"
    Write-Log "Quick Test Mode: $QuickTest" -Level "Info"
    Write-Log "" -Level "Info"
    
    $Success = Test-Applications
    
    Write-Log "=== Application Validation Completed ===" -Level "Info"
    
    if ($Success) {
        exit 0
    }
    else {
        exit 1
    }
}
catch {
    Write-Log "Critical error during application validation: $($_.Exception.Message)" -Level "Error"
    exit 1
}
