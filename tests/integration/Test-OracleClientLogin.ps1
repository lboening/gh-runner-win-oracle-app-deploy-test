# Test-OracleClientLogin.ps1
# Integration test to verify Oracle client can login to local instance

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
    [string]$ConnectionString,
    
    [Parameter(Mandatory = $false)]
    [int]$TimeoutSeconds = 30,
    
    [Parameter(Mandatory = $false)]
    [switch]$CreateTestUser,
    
    [Parameter(Mandatory = $false)]
    [switch]$Verbose
)

# Import logging utility
. "$PSScriptRoot\..\..\scripts\utilities\Write-Log.ps1"

function Get-OracleConnectionString {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Host,
        
        [Parameter(Mandatory = $true)]
        [int]$Port,
        
        [Parameter(Mandatory = $true)]
        [string]$ServiceName,
        
        [Parameter(Mandatory = $true)]
        [string]$Username,
        
        [Parameter(Mandatory = $true)]
        [string]$Password
    )
    
    return "Data Source=${Host}:${Port}/${ServiceName};User Id=${Username};Password=${Password};Connection Timeout=${TimeoutSeconds};"
}

function Test-OracleClientWithSQLPlus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Username,
        
        [Parameter(Mandatory = $true)]
        [string]$Password,
        
        [Parameter(Mandatory = $true)]
        [string]$ServiceName,
        
        [Parameter(Mandatory = $false)]
        [int]$TimeoutSeconds = 30
    )
    
    try {
        # Find SQL*Plus executable
        $SQLPlusPaths = @()
        
        if ($env:ORACLE_HOME) {
            $SQLPlusPaths += Join-Path $env:ORACLE_HOME "bin\sqlplus.exe"
        }
        
        # Common installation paths
        $SQLPlusPaths += @(
            "C:\oraclexe\app\oracle\product\21.3.0\dbhomeXE\bin\sqlplus.exe",
            "C:\oraclexe\app\oracle\product\18.4.0\dbhomeXE\bin\sqlplus.exe",
            "C:\oracle\product\*\*\bin\sqlplus.exe",
            "C:\app\oracle\product\*\*\bin\sqlplus.exe"
        )
        
        $SQLPlusPath = $null
        foreach ($Path in $SQLPlusPaths) {
            if ($Path -contains "*") {
                $ResolvedPaths = Get-ChildItem -Path $Path -ErrorAction SilentlyContinue
                if ($ResolvedPaths) {
                    $SQLPlusPath = $ResolvedPaths[0].FullName
                    break
                }
            }
            elseif (Test-Path $Path) {
                $SQLPlusPath = $Path
                break
            }
        }
        
        if (!$SQLPlusPath) {
            throw "SQL*Plus executable not found"
        }
        
        Write-Log "Using SQL*Plus at: $SQLPlusPath" -Level "Info"
        
        # Create temporary SQL script for testing
        $TempSQLFile = [System.IO.Path]::GetTempFileName() + ".sql"
        $SQLCommands = @"
-- Test connection and basic functionality
SELECT 'Connection successful' as STATUS FROM DUAL;
SELECT USER as CURRENT_USER FROM DUAL;
SELECT TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') as CURRENT_TIME FROM DUAL;
SELECT VERSION FROM V`$INSTANCE;
EXIT;
"@
        
        $SQLCommands | Out-File -FilePath $TempSQLFile -Encoding ASCII
        
        Write-Log "Created temporary SQL script: $TempSQLFile" -Level "Debug"
        
        # Prepare connection string
        $ConnectionString = "${Username}/${Password}@${ServiceName}"
        
        # Execute SQL*Plus
        $ProcessStartInfo = New-Object System.Diagnostics.ProcessStartInfo
        $ProcessStartInfo.FileName = $SQLPlusPath
        $ProcessStartInfo.Arguments = "-S $ConnectionString @`"$TempSQLFile`""
        $ProcessStartInfo.RedirectStandardOutput = $true
        $ProcessStartInfo.RedirectStandardError = $true
        $ProcessStartInfo.UseShellExecute = $false
        $ProcessStartInfo.CreateNoWindow = $true
        
        $Process = New-Object System.Diagnostics.Process
        $Process.StartInfo = $ProcessStartInfo
        
        Write-Log "Executing SQL*Plus connection test..." -Level "Info"
        $Process.Start() | Out-Null
        $Process.WaitForExit($TimeoutSeconds * 1000)
        
        if (!$Process.HasExited) {
            $Process.Kill()
            throw "SQL*Plus connection test timed out after $TimeoutSeconds seconds"
        }
        
        $StandardOutput = $Process.StandardOutput.ReadToEnd()
        $StandardError = $Process.StandardError.ReadToEnd()
        $ExitCode = $Process.ExitCode
        
        # Cleanup temporary file
        Remove-Item $TempSQLFile -Force -ErrorAction SilentlyContinue
        
        Write-Log "SQL*Plus output:" -Level "Debug"
        Write-Log $StandardOutput -Level "Debug"
        
        if ($StandardError) {
            Write-Log "SQL*Plus errors:" -Level "Debug"
            Write-Log $StandardError -Level "Debug"
        }
        
        # Parse output for success indicators
        $ConnectionSuccessful = $false
        $DatabaseInfo = @{}
        
        if ($StandardOutput -match "Connection successful") {
            $ConnectionSuccessful = $true
        }
        
        # Extract database information
        if ($StandardOutput -match "CURRENT_USER\s*\r?\n\s*[-]+\s*\r?\n\s*(\w+)") {
            $DatabaseInfo["CurrentUser"] = $Matches[1]
        }
        
        if ($StandardOutput -match "CURRENT_TIME\s*\r?\n\s*[-]+\s*\r?\n\s*([\d\-:\s]+)") {
            $DatabaseInfo["CurrentTime"] = $Matches[1].Trim()
        }
        
        if ($StandardOutput -match "VERSION\s*\r?\n\s*[-]+\s*\r?\n\s*([\d\.]+)") {
            $DatabaseInfo["Version"] = $Matches[1]
        }
        
        # Check for common error indicators
        $ErrorIndicators = @(
            "ORA-\d+:",
            "TNS-\d+:",
            "SP2-\d+:",
            "ERROR:",
            "invalid username/password"
        )
        
        $HasErrors = $false
        foreach ($ErrorPattern in $ErrorIndicators) {
            if ($StandardOutput -match $ErrorPattern -or $StandardError -match $ErrorPattern) {
                $HasErrors = $true
                break
            }
        }
        
        return @{
            Success = $ConnectionSuccessful -and !$HasErrors -and ($ExitCode -eq 0)
            ExitCode = $ExitCode
            Output = $StandardOutput
            Error = $StandardError
            DatabaseInfo = $DatabaseInfo
        }
    }
    catch {
        return @{
            Success = $false
            ExitCode = -1
            Output = ""
            Error = $_.Exception.Message
            DatabaseInfo = @{}
        }
    }
}

function Test-OracleClientWithODBC {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConnectionString
    )
    
    try {
        Write-Log "Testing Oracle connection using ODBC..." -Level "Info"
        
        # Check if Oracle ODBC driver is available
        $ODBCDrivers = Get-OdbcDriver | Where-Object { $_.Name -like "*Oracle*" }
        
        if (!$ODBCDrivers) {
            Write-Log "No Oracle ODBC drivers found" -Level "Warning"
            return @{
                Success = $false
                Error = "Oracle ODBC driver not installed"
                DriverInfo = @()
            }
        }
        
        Write-Log "Found Oracle ODBC drivers:" -Level "Info"
        $ODBCDrivers | ForEach-Object {
            Write-Log "  - $($_.Name) (Platform: $($_.Platform))" -Level "Info"
        }
        
        # Try to create ODBC connection
        try {
            $Connection = New-Object System.Data.Odbc.OdbcConnection
            $Connection.ConnectionString = $ConnectionString
            $Connection.Open()
            
            # Execute a simple test query
            $Command = $Connection.CreateCommand()
            $Command.CommandText = "SELECT 'ODBC Connection successful' as STATUS, USER as CURRENT_USER FROM DUAL"
            $Command.CommandTimeout = $TimeoutSeconds
            
            $Reader = $Command.ExecuteReader()
            $Results = @()
            
            while ($Reader.Read()) {
                $Results += @{
                    Status = $Reader["STATUS"]
                    CurrentUser = $Reader["CURRENT_USER"]
                }
            }
            
            $Reader.Close()
            $Connection.Close()
            
            return @{
                Success = $true
                Error = ""
                DriverInfo = $ODBCDrivers
                QueryResults = $Results
            }
        }
        catch {
            if ($Connection -and $Connection.State -eq "Open") {
                $Connection.Close()
            }
            
            return @{
                Success = $false
                Error = $_.Exception.Message
                DriverInfo = $ODBCDrivers
                QueryResults = @()
            }
        }
    }
    catch {
        return @{
            Success = $false
            Error = $_.Exception.Message
            DriverInfo = @()
            QueryResults = @()
        }
    }
}

function Test-OracleClientWithODP {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConnectionString
    )
    
    try {
        Write-Log "Testing Oracle connection using Oracle Data Provider (ODP.NET)..." -Level "Info"
        
        # Try to load Oracle.DataAccess assembly
        try {
            Add-Type -AssemblyName "Oracle.DataAccess"
            $UseUnmanaged = $true
        }
        catch {
            try {
                Add-Type -AssemblyName "Oracle.ManagedDataAccess"
                $UseUnmanaged = $false
            }
            catch {
                return @{
                    Success = $false
                    Error = "Oracle Data Provider assemblies not found (neither Oracle.DataAccess nor Oracle.ManagedDataAccess)"
                    Provider = "None"
                }
            }
        }
        
        $ProviderType = if ($UseUnmanaged) { "Oracle.DataAccess (Unmanaged)" } else { "Oracle.ManagedDataAccess (Managed)" }
        Write-Log "Using provider: $ProviderType" -Level "Info"
        
        # Create connection
        if ($UseUnmanaged) {
            $Connection = New-Object Oracle.DataAccess.Client.OracleConnection($ConnectionString)
        }
        else {
            $Connection = New-Object Oracle.ManagedDataAccess.Client.OracleConnection($ConnectionString)
        }
        
        $Connection.Open()
        
        # Execute test query
        if ($UseUnmanaged) {
            $Command = New-Object Oracle.DataAccess.Client.OracleCommand
        }
        else {
            $Command = New-Object Oracle.ManagedDataAccess.Client.OracleCommand
        }
        
        $Command.Connection = $Connection
        $Command.CommandText = "SELECT 'ODP.NET Connection successful' as STATUS, USER as CURRENT_USER, SYSDATE as CURRENT_TIME FROM DUAL"
        $Command.CommandTimeout = $TimeoutSeconds
        
        $Reader = $Command.ExecuteReader()
        $Results = @()
        
        while ($Reader.Read()) {
            $Results += @{
                Status = $Reader["STATUS"].ToString()
                CurrentUser = $Reader["CURRENT_USER"].ToString()
                CurrentTime = $Reader["CURRENT_TIME"].ToString()
            }
        }
        
        $Reader.Close()
        $Connection.Close()
        
        return @{
            Success = $true
            Error = ""
            Provider = $ProviderType
            QueryResults = $Results
        }
    }
    catch {
        if ($Connection -and $Connection.State -eq "Open") {
            $Connection.Close()
        }
        
        return @{
            Success = $false
            Error = $_.Exception.Message
            Provider = $ProviderType
            QueryResults = @()
        }
    }
}

function Get-DefaultOraclePassword {
    # Common default passwords for Oracle XE
    $DefaultPasswords = @(
        "oracle",
        "password",
        "123456",
        "xe",
        "system",
        "admin"
    )
    
    return $DefaultPasswords
}

# Main test execution
try {
    Write-Log "=== Oracle Client Login Integration Test ===" -Level "Info"
    Write-Log "Host: $OracleHost" -Level "Info"
    Write-Log "Port: $OraclePort" -Level "Info"
    Write-Log "Service: $ServiceName" -Level "Info"
    Write-Log "Username: $TestUsername" -Level "Info"
    Write-Log "Timeout: $TimeoutSeconds seconds" -Level "Info"
    Write-Log "" -Level "Info"
    
    # Determine password to use
    if (!$TestPassword) {
        Write-Log "No password provided. Testing with common default passwords..." -Level "Warning"
        $PasswordsToTry = Get-DefaultOraclePassword
    }
    else {
        $PasswordsToTry = @($TestPassword)
    }
    
    # Build connection string if not provided
    if (!$ConnectionString) {
        Write-Log "Building Oracle connection string..." -Level "Info"
    }
    
    $TestResults = @{}
    $OverallSuccess = $false
    $SuccessfulPassword = $null
    
    # Try each password
    foreach ($Password in $PasswordsToTry) {
        Write-Log "Testing password: $('*' * $Password.Length)" -Level "Info"
        
        if (!$ConnectionString) {
            $TestConnectionString = Get-OracleConnectionString -Host $OracleHost -Port $OraclePort -ServiceName $ServiceName -Username $TestUsername -Password $Password
        }
        else {
            $TestConnectionString = $ConnectionString
        }
        
        # Test 1: SQL*Plus connection
        Write-Log "Test 1: SQL*Plus Connection Test" -Level "Info"
        $SQLPlusTest = Test-OracleClientWithSQLPlus -Username $TestUsername -Password $Password -ServiceName $ServiceName -TimeoutSeconds $TimeoutSeconds
        
        if ($SQLPlusTest.Success) {
            Write-Log "✓ SQL*Plus connection successful" -Level "Success"
            $OverallSuccess = $true
            $SuccessfulPassword = $Password
            $TestResults["SQLPlus"] = $SQLPlusTest
            
            # Display database information
            if ($SQLPlusTest.DatabaseInfo.Count -gt 0) {
                Write-Log "Database Information:" -Level "Info"
                $SQLPlusTest.DatabaseInfo.Keys | ForEach-Object {
                    Write-Log "  $_`: $($SQLPlusTest.DatabaseInfo[$_])" -Level "Info"
                }
            }
            
            break
        }
        else {
            Write-Log "✗ SQL*Plus connection failed: $($SQLPlusTest.Error)" -Level "Warning"
        }
        
        Write-Log "" -Level "Info"
    }
    
    if ($OverallSuccess) {
        # Build final connection string for additional tests
        $FinalConnectionString = if ($ConnectionString) { 
            $ConnectionString 
        } else { 
            Get-OracleConnectionString -Host $OracleHost -Port $OraclePort -ServiceName $ServiceName -Username $TestUsername -Password $SuccessfulPassword
        }
        
        # Test 2: ODBC connection (if available)
        Write-Log "Test 2: ODBC Connection Test" -Level "Info"
        $ODBCTest = Test-OracleClientWithODBC -ConnectionString $FinalConnectionString
        $TestResults["ODBC"] = $ODBCTest
        
        if ($ODBCTest.Success) {
            Write-Log "✓ ODBC connection successful" -Level "Success"
            if ($ODBCTest.QueryResults.Count -gt 0) {
                $ODBCTest.QueryResults | ForEach-Object {
                    Write-Log "  Status: $($_.Status)" -Level "Info"
                    Write-Log "  Current User: $($_.CurrentUser)" -Level "Info"
                }
            }
        }
        else {
            Write-Log "✗ ODBC connection failed: $($ODBCTest.Error)" -Level "Warning"
        }
        Write-Log "" -Level "Info"
        
        # Test 3: ODP.NET connection (if available)
        Write-Log "Test 3: ODP.NET Connection Test" -Level "Info"
        $ODPTest = Test-OracleClientWithODP -ConnectionString $FinalConnectionString
        $TestResults["ODP"] = $ODPTest
        
        if ($ODPTest.Success) {
            Write-Log "✓ ODP.NET connection successful using $($ODPTest.Provider)" -Level "Success"
            if ($ODPTest.QueryResults.Count -gt 0) {
                $ODPTest.QueryResults | ForEach-Object {
                    Write-Log "  Status: $($_.Status)" -Level "Info"
                    Write-Log "  Current User: $($_.CurrentUser)" -Level "Info"
                    Write-Log "  Current Time: $($_.CurrentTime)" -Level "Info"
                }
            }
        }
        else {
            Write-Log "✗ ODP.NET connection failed: $($ODPTest.Error)" -Level "Warning"
        }
        Write-Log "" -Level "Info"
    }
    
    # Generate summary report
    Write-Log "=== Test Summary ===" -Level "Info"
    $SuccessfulTests = ($TestResults.Values | Where-Object { $_.Success -eq $true }).Count
    $TotalTests = $TestResults.Count
    
    if ($TotalTests -gt 0) {
        $SuccessRate = [math]::Round(($SuccessfulTests / $TotalTests) * 100, 1)
        Write-Log "Tests Passed: $SuccessfulTests/$TotalTests ($SuccessRate%)" -Level "Info"
    }
    
    if ($OverallSuccess) {
        Write-Log "✓ Oracle client login successful with username: $TestUsername" -Level "Success"
        Write-Log "=== Oracle Client Login Test: PASSED ===" -Level "Success"
        exit 0
    }
    else {
        Write-Log "✗ Oracle client login failed for username: $TestUsername" -Level "Error"
        Write-Log "=== Oracle Client Login Test: FAILED ===" -Level "Error"
        exit 1
    }
}
catch {
    Write-Log "Critical error during Oracle client login test: $($_.Exception.Message)" -Level "Error"
    Write-Log "Stack trace: $($_.Exception.StackTrace)" -Level "Debug"
    exit 1
}
finally {
    Write-Log "Oracle client login integration test completed at $(Get-Date)" -Level "Info"
}
