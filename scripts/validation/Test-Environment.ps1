# Test-Environment.ps1
# Validates the GitHub Runner environment setup

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$LogPath = "C:\Logs\EnvironmentValidation.log"
)

# Import utilities
. "$PSScriptRoot\..\utilities\Write-Log.ps1"

function Test-Environment {
    Write-Log "Starting environment validation..." -Level "Info"
    
    $ValidationResults = @{
        WindowsFeatures = Test-WindowsFeatures
        IISConfiguration = Test-IISConfiguration
        OracleDatabase = Test-OracleDatabase
        GitHubRunner = Test-GitHubRunner
        SystemHealth = Test-SystemHealth
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
            
            if ($Result.Status -eq "Pass") {
                $PassedTests++
                Write-Log "✓ $Test`: $($Result.Message)" -Level "Success"
            }
            else {
                Write-Log "✗ $Test`: $($Result.Message)" -Level "Error"
            }
        }
        Write-Log "" -Level "Info"
    }
    
    # Overall summary
    $SuccessRate = [math]::Round(($PassedTests / $TotalTests) * 100, 1)
    Write-Log "=== Validation Summary ===" -Level "Info"
    Write-Log "Total Tests: $TotalTests" -Level "Info"
    Write-Log "Passed: $PassedTests" -Level "Success"
    Write-Log "Failed: $($TotalTests - $PassedTests)" -Level "Error"
    Write-Log "Success Rate: $SuccessRate%" -Level "Info"
    
    if ($SuccessRate -eq 100) {
        Write-Log "🎉 All validation tests passed! Environment is ready." -Level "Success"
        return $true
    }
    else {
        Write-Log "⚠️ Some validation tests failed. Please check the logs for details." -Level "Warning"
        return $false
    }
}

function Test-WindowsFeatures {
    $Results = @{}
    
    $RequiredFeatures = @(
        "IIS-WebServerRole",
        "IIS-ASPNET45",
        "IIS-NetFx45",
        "IIS-ManagementConsole"
    )
    
    foreach ($Feature in $RequiredFeatures) {
        try {
            $FeatureState = Get-WindowsOptionalFeature -Online -FeatureName $Feature -ErrorAction Stop
            if ($FeatureState.State -eq "Enabled") {
                $Results[$Feature] = @{ Status = "Pass"; Message = "Feature is enabled" }
            }
            else {
                $Results[$Feature] = @{ Status = "Fail"; Message = "Feature is not enabled" }
            }
        }
        catch {
            $Results[$Feature] = @{ Status = "Fail"; Message = "Feature not found or error checking status" }
        }
    }
    
    return $Results
}

function Test-IISConfiguration {
    $Results = @{}
    
    # Test IIS Service
    try {
        $IISService = Get-Service -Name "W3SVC" -ErrorAction Stop
        if ($IISService.Status -eq "Running") {
            $Results["IIS_Service"] = @{ Status = "Pass"; Message = "IIS service is running" }
        }
        else {
            $Results["IIS_Service"] = @{ Status = "Fail"; Message = "IIS service is not running" }
        }
    }
    catch {
        $Results["IIS_Service"] = @{ Status = "Fail"; Message = "IIS service not found" }
    }
    
    # Test Default Website
    try {
        $Response = Invoke-WebRequest -Uri "http://localhost" -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        if ($Response.StatusCode -eq 200) {
            $Results["Default_Website"] = @{ Status = "Pass"; Message = "Default website is responding" }
        }
        else {
            $Results["Default_Website"] = @{ Status = "Fail"; Message = "Default website returned status code $($Response.StatusCode)" }
        }
    }
    catch {
        $Results["Default_Website"] = @{ Status = "Fail"; Message = "Cannot connect to default website" }
    }
    
    return $Results
}

function Test-OracleDatabase {
    $Results = @{}
    
    # Test Oracle Service
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
    
    # Test Oracle Connectivity
    try {
        $TnsPath = "$env:ORACLE_HOME\bin\tnsping.exe"
        if (Test-Path $TnsPath) {
            $TnsResult = & $TnsPath "XE"
            if ($LASTEXITCODE -eq 0) {
                $Results["Oracle_Connectivity"] = @{ Status = "Pass"; Message = "Oracle TNS listener is responding" }
            }
            else {
                $Results["Oracle_Connectivity"] = @{ Status = "Fail"; Message = "Oracle TNS listener is not responding" }
            }
        }
        else {
            $Results["Oracle_Connectivity"] = @{ Status = "Fail"; Message = "Oracle TNS utilities not found" }
        }
    }
    catch {
        $Results["Oracle_Connectivity"] = @{ Status = "Fail"; Message = "Error testing Oracle connectivity" }
    }
    
    return $Results
}

function Test-GitHubRunner {
    $Results = @{}
    
    # Test GitHub Runner Service
    try {
        $RunnerServices = Get-Service -Name "actions.runner.*" -ErrorAction SilentlyContinue
        if ($RunnerServices) {
            $RunningServices = $RunnerServices | Where-Object { $_.Status -eq "Running" }
            if ($RunningServices) {
                $Results["Runner_Service"] = @{ Status = "Pass"; Message = "$($RunningServices.Count) runner service(s) running" }
            }
            else {
                $Results["Runner_Service"] = @{ Status = "Fail"; Message = "Runner services found but not running" }
            }
        }
        else {
            $Results["Runner_Service"] = @{ Status = "Fail"; Message = "No GitHub runner services found" }
        }
    }
    catch {
        $Results["Runner_Service"] = @{ Status = "Fail"; Message = "Error checking runner services" }
    }
    
    # Test Runner Directory
    $RunnerPath = "C:\actions-runner"
    if (Test-Path $RunnerPath) {
        $Results["Runner_Installation"] = @{ Status = "Pass"; Message = "Runner installation directory exists" }
    }
    else {
        $Results["Runner_Installation"] = @{ Status = "Fail"; Message = "Runner installation directory not found" }
    }
    
    return $Results
}

function Test-SystemHealth {
    $Results = @{}
    
    # Test disk space
    try {
        $SystemDrive = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DeviceID -eq "C:" }
        $FreeSpaceGB = [math]::Round($SystemDrive.FreeSpace / 1GB, 1)
        
        if ($FreeSpaceGB -gt 10) {
            $Results["Disk_Space"] = @{ Status = "Pass"; Message = "$FreeSpaceGB GB free space available" }
        }
        else {
            $Results["Disk_Space"] = @{ Status = "Fail"; Message = "Low disk space: $FreeSpaceGB GB remaining" }
        }
    }
    catch {
        $Results["Disk_Space"] = @{ Status = "Fail"; Message = "Error checking disk space" }
    }
    
    # Test memory
    try {
        $Memory = Get-WmiObject -Class Win32_ComputerSystem
        $TotalMemoryGB = [math]::Round($Memory.TotalPhysicalMemory / 1GB, 1)
        
        if ($TotalMemoryGB -ge 8) {
            $Results["Memory"] = @{ Status = "Pass"; Message = "$TotalMemoryGB GB total memory" }
        }
        else {
            $Results["Memory"] = @{ Status = "Fail"; Message = "Insufficient memory: $TotalMemoryGB GB" }
        }
    }
    catch {
        $Results["Memory"] = @{ Status = "Fail"; Message = "Error checking memory" }
    }
    
    return $Results
}

function Test-OracleIntegration {
    Write-Log "Running comprehensive Oracle integration tests..." -Level "Info"
    
    try {
        $IntegrationTestPath = "$PSScriptRoot\..\..\tests\integration\Test-OracleIntegration.ps1"
        
        if (Test-Path $IntegrationTestPath) {
            Write-Log "Executing Oracle integration test suite..." -Level "Info"
            
            # Execute the integration tests
            $Result = & $IntegrationTestPath -ContinueOnFailure
            
            if ($LASTEXITCODE -eq 0) {
                Write-Log "✓ Oracle integration tests passed" -Level "Success"
                return $true
            }
            else {
                Write-Log "✗ Oracle integration tests failed" -Level "Error"
                return $false
            }
        }
        else {
            Write-Log "Oracle integration test suite not found at: $IntegrationTestPath" -Level "Warning"
            return $false
        }
    }
    catch {
        Write-Log "Error running Oracle integration tests: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

# Execute main function
Test-Environment

# Optionally run integration tests
if ($args -contains "-IncludeIntegration") {
    Write-Log "" -Level "Info"
    Write-Log "=== Running Integration Tests ===" -Level "Info"
    Test-OracleIntegration
}
