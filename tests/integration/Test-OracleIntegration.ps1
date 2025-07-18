# Test-OracleIntegration.ps1
# Master test runner for Oracle integration tests

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OracleHost = "localhost",
    
    [Parameter(Mandatory = $false)]
    [int]$OraclePort = 1521,
    
    [Parameter(Mandatory = $false)]
    [string]$ServiceName = "XE",
    
    [Parameter(Mandatory = $false)]
    [string]$TestUsername = "system",
    
    [Parameter(Mandatory = $false)]
    [string]$TestPassword,
    
    [Parameter(Mandatory = $false)]
    [int]$TimeoutSeconds = 30,
    
    [Parameter(Mandatory = $false)]
    [switch]$ListenerOnly,
    
    [Parameter(Mandatory = $false)]
    [switch]$LoginOnly,
    
    [Parameter(Mandatory = $false)]
    [switch]$ContinueOnFailure,
    
    [Parameter(Mandatory = $false)]
    [string]$LogFile = "C:\Logs\OracleIntegrationTest_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
)

# Import logging utility
. "$PSScriptRoot\..\..\scripts\utilities\Write-Log.ps1"

function Invoke-TestScript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,
        
        [Parameter(Mandatory = $true)]
        [string]$TestName,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Parameters,
        
        [Parameter(Mandatory = $false)]
        [int]$TimeoutMinutes = 5
    )
    
    try {
        Write-Log "Starting test: $TestName" -Level "Info"
        Write-Log "Script: $ScriptPath" -Level "Info"
        
        if (!(Test-Path $ScriptPath)) {
            throw "Test script not found: $ScriptPath"
        }
        
        # Build parameter string
        $ParamString = ""
        foreach ($Key in $Parameters.Keys) {
            $Value = $Parameters[$Key]
            if ($Value -is [switch] -or $Value -is [bool]) {
                if ($Value) {
                    $ParamString += " -$Key"
                }
            }
            else {
                $ParamString += " -$Key `"$Value`""
            }
        }
        
        Write-Log "Parameters: $ParamString" -Level "Debug"
        
        # Execute the test script
        $ProcessStartInfo = New-Object System.Diagnostics.ProcessStartInfo
        $ProcessStartInfo.FileName = "PowerShell.exe"
        $ProcessStartInfo.Arguments = "-ExecutionPolicy Bypass -File `"$ScriptPath`"$ParamString"
        $ProcessStartInfo.RedirectStandardOutput = $true
        $ProcessStartInfo.RedirectStandardError = $true
        $ProcessStartInfo.UseShellExecute = $false
        $ProcessStartInfo.CreateNoWindow = $true
        $ProcessStartInfo.WorkingDirectory = Split-Path $ScriptPath -Parent
        
        $Process = New-Object System.Diagnostics.Process
        $Process.StartInfo = $ProcessStartInfo
        
        $Process.Start() | Out-Null
        $Process.WaitForExit($TimeoutMinutes * 60 * 1000)
        
        if (!$Process.HasExited) {
            $Process.Kill()
            throw "Test timed out after $TimeoutMinutes minutes"
        }
        
        $StandardOutput = $Process.StandardOutput.ReadToEnd()
        $StandardError = $Process.StandardError.ReadToEnd()
        $ExitCode = $Process.ExitCode
        
        # Log the output
        if ($StandardOutput) {
            Write-Log "Test output:" -Level "Debug"
            $StandardOutput -split "`n" | ForEach-Object {
                if ($_.Trim()) {
                    Write-Log "  $_" -Level "Debug"
                }
            }
        }
        
        if ($StandardError) {
            Write-Log "Test errors:" -Level "Debug"
            $StandardError -split "`n" | ForEach-Object {
                if ($_.Trim()) {
                    Write-Log "  $_" -Level "Debug"
                }
            }
        }
        
        return @{
            Success = ($ExitCode -eq 0)
            ExitCode = $ExitCode
            Output = $StandardOutput
            Error = $StandardError
            TestName = $TestName
        }
    }
    catch {
        return @{
            Success = $false
            ExitCode = -1
            Output = ""
            Error = $_.Exception.Message
            TestName = $TestName
        }
    }
}

function Show-TestSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$TestResults
    )
    
    Write-Log "================================================================" -Level "Info"
    Write-Log "                    TEST EXECUTION SUMMARY" -Level "Info"
    Write-Log "================================================================" -Level "Info"
    
    $PassedTests = 0
    $FailedTests = 0
    
    foreach ($Result in $TestResults) {
        $Status = if ($Result.Success) { "PASSED" } else { "FAILED" }
        $StatusColor = if ($Result.Success) { "Success" } else { "Error" }
        
        Write-Log "$($Result.TestName): $Status" -Level $StatusColor
        
        if ($Result.Success) {
            $PassedTests++
        }
        else {
            $FailedTests++
            if ($Result.Error) {
                Write-Log "  Error: $($Result.Error)" -Level "Error"
            }
        }
    }
    
    $TotalTests = $TestResults.Count
    $SuccessRate = if ($TotalTests -gt 0) { [math]::Round(($PassedTests / $TotalTests) * 100, 1) } else { 0 }
    
    Write-Log "================================================================" -Level "Info"
    Write-Log "Total Tests: $TotalTests" -Level "Info"
    Write-Log "Passed: $PassedTests" -Level "Success"
    Write-Log "Failed: $FailedTests" -Level $(if ($FailedTests -gt 0) { "Error" } else { "Info" })
    Write-Log "Success Rate: $SuccessRate%" -Level $(if ($SuccessRate -eq 100) { "Success" } else { "Warning" })
    Write-Log "================================================================" -Level "Info"
    
    return @{
        TotalTests = $TotalTests
        PassedTests = $PassedTests
        FailedTests = $FailedTests
        SuccessRate = $SuccessRate
        AllPassed = ($FailedTests -eq 0)
    }
}

function Test-Prerequisites {
    try {
        Write-Log "Checking test prerequisites..." -Level "Info"
        
        $Prerequisites = @{
            "PowerShell Version" = $PSVersionTable.PSVersion.ToString()
            "Operating System" = (Get-WmiObject Win32_OperatingSystem).Caption
            "Current User" = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
            "Test Directory" = $PSScriptRoot
        }
        
        Write-Log "Environment Information:" -Level "Info"
        foreach ($Key in $Prerequisites.Keys) {
            Write-Log "  $Key`: $($Prerequisites[$Key])" -Level "Info"
        }
        
        # Check if Oracle client tools are available
        $OracleChecks = @{
            "ORACLE_HOME" = $env:ORACLE_HOME
            "TNS_ADMIN" = $env:TNS_ADMIN
            "ORACLE_SID" = $env:ORACLE_SID
        }
        
        Write-Log "Oracle Environment:" -Level "Info"
        foreach ($Key in $OracleChecks.Keys) {
            $Value = $OracleChecks[$Key]
            if ($Value) {
                Write-Log "  $Key`: $Value" -Level "Info"
            }
            else {
                Write-Log "  $Key`: (not set)" -Level "Warning"
            }
        }
        
        return $true
    }
    catch {
        Write-Log "Error checking prerequisites: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

# Main execution
try {
    Write-Log "================================================================" -Level "Info"
    Write-Log "             ORACLE INTEGRATION TEST SUITE" -Level "Info"
    Write-Log "================================================================" -Level "Info"
    Write-Log "Start Time: $(Get-Date)" -Level "Info"
    Write-Log "Log File: $LogFile" -Level "Info"
    Write-Log "" -Level "Info"
    
    # Check prerequisites
    if (!(Test-Prerequisites)) {
        Write-Log "Prerequisites check failed. Aborting tests." -Level "Error"
        exit 1
    }
    
    Write-Log "" -Level "Info"
    
    # Prepare test parameters
    $CommonParams = @{
        OracleHost = $OracleHost
        OraclePort = $OraclePort
        ServiceName = $ServiceName
        TimeoutSeconds = $TimeoutSeconds
        Verbose = $Verbose
    }
    
    $TestResults = @()
    
    # Test 1: Oracle Listener Test
    if (!$LoginOnly) {
        Write-Log "================================================================" -Level "Info"
        Write-Log "                   TEST 1: ORACLE LISTENER" -Level "Info"
        Write-Log "================================================================" -Level "Info"
        
        $ListenerTestPath = Join-Path $PSScriptRoot "Test-OracleListener.ps1"
        $ListenerResult = Invoke-TestScript -ScriptPath $ListenerTestPath -TestName "Oracle Listener Response" -Parameters $CommonParams
        $TestResults += $ListenerResult
        
        if (!$ListenerResult.Success -and !$ContinueOnFailure) {
            Write-Log "Oracle Listener test failed. Skipping remaining tests." -Level "Error"
            Write-Log "Use -ContinueOnFailure to run all tests regardless of failures." -Level "Info"
        }
        else {
            Write-Log "" -Level "Info"
        }
    }
    
    # Test 2: Oracle Client Login Test
    if (!$ListenerOnly -and ($ContinueOnFailure -or !$TestResults -or $TestResults[-1].Success)) {
        Write-Log "================================================================" -Level "Info"
        Write-Log "                  TEST 2: ORACLE CLIENT LOGIN" -Level "Info"
        Write-Log "================================================================" -Level "Info"
        
        $LoginParams = $CommonParams.Clone()
        $LoginParams["TestUsername"] = $TestUsername
        if ($TestPassword) {
            $LoginParams["TestPassword"] = $TestPassword
        }
        
        $LoginTestPath = Join-Path $PSScriptRoot "Test-OracleClientLogin.ps1"
        $LoginResult = Invoke-TestScript -ScriptPath $LoginTestPath -TestName "Oracle Client Login" -Parameters $LoginParams
        $TestResults += $LoginResult
    }
    
    # Generate final summary
    Write-Log "" -Level "Info"
    $Summary = Show-TestSummary -TestResults $TestResults
    
    # Export results to file
    try {
        $ResultsFile = $LogFile -replace "\.log$", "_Results.json"
        $TestResults | ConvertTo-Json -Depth 3 | Out-File -FilePath $ResultsFile -Encoding UTF8
        Write-Log "Test results exported to: $ResultsFile" -Level "Info"
    }
    catch {
        Write-Log "Failed to export test results: $($_.Exception.Message)" -Level "Warning"
    }
    
    Write-Log "" -Level "Info"
    Write-Log "Oracle Integration Test Suite completed at $(Get-Date)" -Level "Info"
    
    # Exit with appropriate code
    if ($Summary.AllPassed) {
        Write-Log "All tests passed successfully!" -Level "Success"
        exit 0
    }
    else {
        Write-Log "Some tests failed. Check the logs for details." -Level "Error"
        exit 1
    }
}
catch {
    Write-Log "Critical error during test execution: $($_.Exception.Message)" -Level "Error"
    Write-Log "Stack trace: $($_.Exception.StackTrace)" -Level "Debug"
    exit 1
}
finally {
    Write-Log "Test suite execution completed." -Level "Info"
}
