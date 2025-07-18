# Test-OracleListener.ps1
# Integration test to verify Oracle listener responds on localhost

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OracleHost = "localhost",
    
    [Parameter(Mandatory = $false)]
    [int]$OraclePort = 1521,
    
    [Parameter(Mandatory = $false)]
    [string]$ServiceName = "XE",
    
    [Parameter(Mandatory = $false)]
    [int]$TimeoutSeconds = 30,
    
    [Parameter(Mandatory = $false)]
    [switch]$Verbose
)

# Import logging utility
. "$PSScriptRoot\..\..\scripts\utilities\Write-Log.ps1"

function Test-TCPConnection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ComputerName,
        
        [Parameter(Mandatory = $true)]
        [int]$Port,
        
        [Parameter(Mandatory = $false)]
        [int]$TimeoutMs = 5000
    )
    
    try {
        $TCPClient = New-Object System.Net.Sockets.TcpClient
        $Connect = $TCPClient.BeginConnect($ComputerName, $Port, $null, $null)
        $Wait = $Connect.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
        
        if ($Wait) {
            try {
                $TCPClient.EndConnect($Connect)
                $Connected = $true
            }
            catch {
                $Connected = $false
            }
        }
        else {
            $Connected = $false
        }
        
        $TCPClient.Close()
        return $Connected
    }
    catch {
        return $false
    }
}

function Test-OracleListenerWithTNSPing {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ServiceName,
        
        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 30
    )
    
    try {
        # Check if ORACLE_HOME is set
        if (!$env:ORACLE_HOME) {
            Write-Log "ORACLE_HOME environment variable not set" -Level "Warning"
            
            # Try to find Oracle installation
            $PossiblePaths = @(
                "C:\oraclexe\app\oracle\product\21.3.0\dbhomeXE",
                "C:\oraclexe\app\oracle\product\18.4.0\dbhomeXE",
                "C:\oracle\product\*\*",
                "C:\app\oracle\product\*\*"
            )
            
            foreach ($Path in $PossiblePaths) {
                $ResolvedPaths = Get-ChildItem -Path $Path -ErrorAction SilentlyContinue | Where-Object { $_.PSIsContainer }
                if ($ResolvedPaths) {
                    $env:ORACLE_HOME = $ResolvedPaths[0].FullName
                    Write-Log "Found Oracle installation at: $env:ORACLE_HOME" -Level "Info"
                    break
                }
            }
        }
        
        if (!$env:ORACLE_HOME) {
            throw "Oracle installation not found"
        }
        
        $TNSPingPath = Join-Path $env:ORACLE_HOME "bin\tnsping.exe"
        
        if (!(Test-Path $TNSPingPath)) {
            throw "TNSPing utility not found at: $TNSPingPath"
        }
        
        Write-Log "Testing Oracle listener using TNSPing..." -Level "Info"
        Write-Log "Service: $ServiceName" -Level "Info"
        Write-Log "TNSPing Path: $TNSPingPath" -Level "Info"
        
        # Execute tnsping with timeout
        $ProcessStartInfo = New-Object System.Diagnostics.ProcessStartInfo
        $ProcessStartInfo.FileName = $TNSPingPath
        $ProcessStartInfo.Arguments = $ServiceName
        $ProcessStartInfo.RedirectStandardOutput = $true
        $ProcessStartInfo.RedirectStandardError = $true
        $ProcessStartInfo.UseShellExecute = $false
        $ProcessStartInfo.CreateNoWindow = $true
        
        $Process = New-Object System.Diagnostics.Process
        $Process.StartInfo = $ProcessStartInfo
        
        $Process.Start() | Out-Null
        $Process.WaitForExit($TimeoutSeconds * 1000)
        
        if (!$Process.HasExited) {
            $Process.Kill()
            throw "TNSPing timed out after $TimeoutSeconds seconds"
        }
        
        $StandardOutput = $Process.StandardOutput.ReadToEnd()
        $StandardError = $Process.StandardError.ReadToEnd()
        $ExitCode = $Process.ExitCode
        
        Write-Log "TNSPing output:" -Level "Debug"
        Write-Log $StandardOutput -Level "Debug"
        
        if ($StandardError) {
            Write-Log "TNSPing errors:" -Level "Debug"
            Write-Log $StandardError -Level "Debug"
        }
        
        # Check if the output indicates successful connection
        $SuccessIndicators = @(
            "OK \((\d+) msec\)",
            "Used TNSNAMES adapter",
            "Attempting to contact"
        )
        
        $Success = $false
        foreach ($Indicator in $SuccessIndicators) {
            if ($StandardOutput -match $Indicator) {
                $Success = $true
                break
            }
        }
        
        return @{
            Success = $Success -and ($ExitCode -eq 0)
            ExitCode = $ExitCode
            Output = $StandardOutput
            Error = $StandardError
        }
    }
    catch {
        return @{
            Success = $false
            ExitCode = -1
            Output = ""
            Error = $_.Exception.Message
        }
    }
}

function Test-OracleListenerWithNetstat {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$Port
    )
    
    try {
        Write-Log "Testing Oracle listener using netstat..." -Level "Info"
        
        # Use netstat to check if the port is listening
        $NetstatOutput = netstat -an | Select-String ":$Port\s"
        
        if ($NetstatOutput) {
            $ListeningPorts = $NetstatOutput | Where-Object { $_ -match "LISTENING" }
            
            if ($ListeningPorts) {
                Write-Log "Found listening ports:" -Level "Info"
                $ListeningPorts | ForEach-Object {
                    Write-Log "  $_" -Level "Info"
                }
                return $true
            }
        }
        
        return $false
    }
    catch {
        Write-Log "Error checking netstat: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

function Test-OracleService {
    try {
        Write-Log "Checking Oracle service status..." -Level "Info"
        
        # Check for various Oracle service names
        $ServiceNames = @(
            "OracleServiceXE",
            "OracleXETNSListener",
            "Oracle*"
        )
        
        $FoundServices = @()
        
        foreach ($ServiceName in $ServiceNames) {
            $Services = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
            if ($Services) {
                $FoundServices += $Services
            }
        }
        
        if ($FoundServices.Count -eq 0) {
            Write-Log "No Oracle services found" -Level "Warning"
            return $false
        }
        
        Write-Log "Found Oracle services:" -Level "Info"
        
        $AllRunning = $true
        foreach ($Service in $FoundServices) {
            $Status = if ($Service.Status -eq "Running") { "✓" } else { "✗" }
            Write-Log "  $Status $($Service.Name): $($Service.Status)" -Level "Info"
            
            if ($Service.Status -ne "Running") {
                $AllRunning = $false
            }
        }
        
        return $AllRunning
    }
    catch {
        Write-Log "Error checking Oracle services: $($_.Exception.Message)" -Level "Error"
        return $false
    }
}

# Main test execution
try {
    Write-Log "=== Oracle Listener Integration Test ===" -Level "Info"
    Write-Log "Host: $OracleHost" -Level "Info"
    Write-Log "Port: $OraclePort" -Level "Info"
    Write-Log "Service: $ServiceName" -Level "Info"
    Write-Log "Timeout: $TimeoutSeconds seconds" -Level "Info"
    Write-Log "" -Level "Info"
    
    $TestResults = @{}
    $OverallSuccess = $true
    
    # Test 1: Check Oracle services
    Write-Log "Test 1: Oracle Service Status" -Level "Info"
    $ServiceTest = Test-OracleService
    $TestResults["ServiceStatus"] = $ServiceTest
    
    if ($ServiceTest) {
        Write-Log "✓ Oracle services are running" -Level "Success"
    }
    else {
        Write-Log "✗ Oracle services are not running properly" -Level "Error"
        $OverallSuccess = $false
    }
    Write-Log "" -Level "Info"
    
    # Test 2: TCP connection to Oracle port
    Write-Log "Test 2: TCP Connection to Oracle Port" -Level "Info"
    $TCPTest = Test-TCPConnection -ComputerName $OracleHost -Port $OraclePort -TimeoutMs ($TimeoutSeconds * 1000)
    $TestResults["TCPConnection"] = $TCPTest
    
    if ($TCPTest) {
        Write-Log "✓ TCP connection to ${OracleHost}:${OraclePort} successful" -Level "Success"
    }
    else {
        Write-Log "✗ TCP connection to ${OracleHost}:${OraclePort} failed" -Level "Error"
        $OverallSuccess = $false
    }
    Write-Log "" -Level "Info"
    
    # Test 3: Netstat verification
    Write-Log "Test 3: Port Listening Verification" -Level "Info"
    $NetstatTest = Test-OracleListenerWithNetstat -Port $OraclePort
    $TestResults["PortListening"] = $NetstatTest
    
    if ($NetstatTest) {
        Write-Log "✓ Oracle listener is listening on port $OraclePort" -Level "Success"
    }
    else {
        Write-Log "✗ Oracle listener is not listening on port $OraclePort" -Level "Error"
        $OverallSuccess = $false
    }
    Write-Log "" -Level "Info"
    
    # Test 4: TNSPing test
    Write-Log "Test 4: TNSPing Listener Test" -Level "Info"
    $TNSTest = Test-OracleListenerWithTNSPing -ServiceName $ServiceName -TimeoutSeconds $TimeoutSeconds
    $TestResults["TNSPing"] = $TNSTest
    
    if ($TNSTest.Success) {
        Write-Log "✓ TNSPing to service '$ServiceName' successful" -Level "Success"
        if ($TNSTest.Output -match "OK \((\d+) msec\)") {
            $ResponseTime = $Matches[1]
            Write-Log "  Response time: $ResponseTime ms" -Level "Info"
        }
    }
    else {
        Write-Log "✗ TNSPing to service '$ServiceName' failed" -Level "Error"
        Write-Log "  Error: $($TNSTest.Error)" -Level "Error"
        $OverallSuccess = $false
    }
    Write-Log "" -Level "Info"
    
    # Generate summary report
    Write-Log "=== Test Summary ===" -Level "Info"
    $PassedTests = ($TestResults.Values | Where-Object { $_ -eq $true -or $_.Success -eq $true }).Count
    $TotalTests = $TestResults.Count
    $SuccessRate = [math]::Round(($PassedTests / $TotalTests) * 100, 1)
    
    Write-Log "Tests Passed: $PassedTests/$TotalTests ($SuccessRate%)" -Level "Info"
    
    if ($OverallSuccess) {
        Write-Log "=== Oracle Listener Test: PASSED ===" -Level "Success"
        exit 0
    }
    else {
        Write-Log "=== Oracle Listener Test: FAILED ===" -Level "Error"
        exit 1
    }
}
catch {
    Write-Log "Critical error during Oracle listener test: $($_.Exception.Message)" -Level "Error"
    Write-Log "Stack trace: $($_.Exception.StackTrace)" -Level "Debug"
    exit 1
}
finally {
    Write-Log "Oracle listener integration test completed at $(Get-Date)" -Level "Info"
}
