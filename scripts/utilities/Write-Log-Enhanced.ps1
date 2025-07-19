# Write-Log-Enhanced.ps1
# Enhanced utility function for Azure Monitor integration with advanced features

# Global variables for batching
$Global:LogBatch = @()
$Global:LastBatchSent = Get-Date
$Global:BatchLock = New-Object System.Object

function Write-LogEnhanced {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Info", "Warning", "Error", "Success", "Debug", "Trace", "Critical")]
        [string]$Level = "Info",
        
        [Parameter(Mandatory = $false)]
        [string]$LogFile = "C:\Logs\GitHubRunner_$(Get-Date -Format 'yyyyMMdd').log",
        
        [Parameter(Mandatory = $false)]
        [string]$Component = "GitHubRunner",
        
        [Parameter(Mandatory = $false)]
        [hashtable]$CustomProperties = @{},
        
        [Parameter(Mandatory = $false)]
        [string]$OperationId = $null,
        
        [Parameter(Mandatory = $false)]
        [string]$CorrelationId = $null,
        
        [Parameter(Mandatory = $false)]
        [switch]$EnableAzureMonitor,
        
        [Parameter(Mandatory = $false)]
        [string]$ConfigFile = "$PSScriptRoot\..\..\configs\azure-monitor-config.json",
        
        [Parameter(Mandatory = $false)]
        [double]$Duration = $null,
        
        [Parameter(Mandatory = $false)]
        [string]$EventName = $null,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Metrics = @{}
    )
    
    # Load configuration
    $Config = @{}
    if (Test-Path $ConfigFile) {
        try {
            $Config = Get-Content $ConfigFile | ConvertFrom-Json -AsHashtable
        }
        catch {
            Write-Warning "Failed to load Azure Monitor config: $($_.Exception.Message)"
        }
    }
    
    $AzureMonitorEnabled = $EnableAzureMonitor -or $Config.azureMonitor.enabled
    
    $Timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffZ"
    $LogMessage = "[$Timestamp] [$Level] $Message"
    
    # Create enhanced structured log entry
    $StructuredLogEntry = @{
        TimeGenerated = $Timestamp
        Level = $Level
        Message = $Message
        Component = $Component
        Computer = $env:COMPUTERNAME
        User = $env:USERNAME
        ProcessId = $PID
        ThreadId = [System.Threading.Thread]::CurrentThread.ManagedThreadId
        OperationId = if ($OperationId) { $OperationId } else { [System.Guid]::NewGuid().ToString() }
        CorrelationId = $CorrelationId
        SessionId = if ($env:SESSIONNAME) { $env:SESSIONNAME } else { "Console" }
        EventName = $EventName
        Duration = $Duration
        # Performance metrics
        MemoryUsageMB = [Math]::Round((Get-Process -Id $PID).WorkingSet64 / 1MB, 2)
        CPUTimeSeconds = [Math]::Round((Get-Process -Id $PID).TotalProcessorTime.TotalSeconds, 2)
        # Azure context
        AzureResourceId = "/subscriptions/$($Config.customFields.subscriptionId)/resourceGroups/$($Config.customFields.resourceGroup)"
        Environment = $Config.customFields.environment
        Region = $Config.customFields.region
        ApplicationVersion = $Config.customFields.applicationVersion
    }
    
    # Add custom properties
    foreach ($key in $CustomProperties.Keys) {
        $StructuredLogEntry[$key] = $CustomProperties[$key]
    }
    
    # Add metrics
    foreach ($key in $Metrics.Keys) {
        $StructuredLogEntry["Metric_$key"] = $Metrics[$key]
    }
    
    # Console output with enhanced formatting
    $ColorMap = @{
        "Trace" = "DarkGray"
        "Debug" = "Gray"
        "Info" = "White"
        "Warning" = "Yellow"
        "Error" = "Red"
        "Critical" = "Magenta"
        "Success" = "Green"
    }
    
    Write-Host $LogMessage -ForegroundColor $ColorMap[$Level]
    if ($Duration) {
        Write-Host "    Duration: $($Duration)ms" -ForegroundColor $ColorMap[$Level]
    }
    
    # Ensure log directory exists
    $LogDir = Split-Path $LogFile -Parent
    if (!(Test-Path $LogDir)) {
        New-Item -Path $LogDir -ItemType Directory -Force | Out-Null
    }
    
    # File output with rotation
    try {
        # Check file size and rotate if needed (100MB limit)
        if ((Test-Path $LogFile) -and (Get-Item $LogFile).Length -gt 100MB) {
            $RotatedFile = $LogFile -replace '\.log$', "_$(Get-Date -Format 'HHmmss').log"
            Move-Item $LogFile $RotatedFile
            
            # Compress old log if configured
            if ($Config.logging.compressOldLogs) {
                Compress-Archive -Path $RotatedFile -DestinationPath "$RotatedFile.zip" -Force
                Remove-Item $RotatedFile
            }
        }
        
        # Write human-readable log
        $LogMessage | Out-File -FilePath $LogFile -Append -Encoding UTF8
        
        # Write structured JSON log
        if ($Config.logging.enableStructuredLogging) {
            $JsonLogFile = $LogFile -replace '\.log$', '_structured.jsonl'
            ($StructuredLogEntry | ConvertTo-Json -Compress) | Out-File -FilePath $JsonLogFile -Append -Encoding UTF8
        }
    }
    catch {
        Write-Warning "Failed to write to log file: $($_.Exception.Message)"
    }
    
    # Windows Event Log with enhanced event IDs
    try {
        if (![System.Diagnostics.EventLog]::SourceExists("GitHubRunner")) {
            New-EventLog -LogName "Application" -Source "GitHubRunner"
        }
        
        $EventType = switch ($Level) {
            "Critical" { "Error" }
            "Error" { "Error" }
            "Warning" { "Warning" }
            default { "Information" }
        }
        
        $EventId = switch ($Level) {
            "Critical" { 1000 }
            "Error" { 1001 }
            "Warning" { 1002 }
            "Success" { 1003 }
            default { 1004 }
        }
        
        $EventMessage = if ($CustomProperties.Count -gt 0 -or $Metrics.Count -gt 0) {
            "$Message`n`nAdditional Data:`n$($StructuredLogEntry | ConvertTo-Json)"
        } else {
            $Message
        }
        
        Write-EventLog -LogName "Application" -Source "GitHubRunner" -EventId $EventId -EntryType $EventType -Message $EventMessage
    }
    catch {
        # Silently ignore event log errors to prevent infinite loops
    }
    
    # Azure Monitor integration with batching
    if ($AzureMonitorEnabled) {
        if ($Config.logging.enableBatching) {
            Add-ToBatch -LogEntry $StructuredLogEntry -Config $Config
        } else {
            Send-ToAzureMonitorDirect -LogEntry $StructuredLogEntry -Config $Config
        }
    }
}

function Add-ToBatch {
    param($LogEntry, $Config)
    
    [System.Threading.Monitor]::Enter($Global:BatchLock)
    try {
        $Global:LogBatch += $LogEntry
        
        $BatchSize = if ($Config.azureMonitor.batchSize) { $Config.azureMonitor.batchSize } else { 100 }
        $BatchTimeout = if ($Config.azureMonitor.batchTimeout) { $Config.azureMonitor.batchTimeout } else { 30 }
        
        $ShouldSend = $Global:LogBatch.Count -ge $BatchSize -or 
                      (Get-Date).Subtract($Global:LastBatchSent).TotalSeconds -ge $BatchTimeout
        
        if ($ShouldSend -and $Global:LogBatch.Count -gt 0) {
            $BatchToSend = $Global:LogBatch.Clone()
            $Global:LogBatch = @()
            $Global:LastBatchSent = Get-Date
            
            # Send batch asynchronously
            Start-Job -ScriptBlock {
                param($Batch, $Config)
                . $using:PSScriptRoot\Write-Log-Enhanced.ps1
                Send-ToAzureMonitorBatch -LogEntries $Batch -Config $Config
            } -ArgumentList $BatchToSend, $Config | Out-Null
        }
    }
    finally {
        [System.Threading.Monitor]::Exit($Global:BatchLock)
    }
}

function Send-ToAzureMonitorDirect {
    param($LogEntry, $Config)
    
    try {
        Send-ToAzureMonitorBatch -LogEntries @($LogEntry) -Config $Config
    }
    catch {
        Write-Warning "Failed to send log to Azure Monitor: $($_.Exception.Message)"
    }
}

function Send-ToAzureMonitorBatch {
    param($LogEntries, $Config)
    
    if (-not $Config.azureMonitor.workspaceId -or -not $Config.azureMonitor.sharedKey) {
        Write-Warning "Azure Monitor workspace ID or shared key not configured"
        return
    }
    
    $WorkspaceId = $Config.azureMonitor.workspaceId
    $SharedKey = $Config.azureMonitor.sharedKey
    $LogType = if ($Config.azureMonitor.logType) { $Config.azureMonitor.logType } else { "GitHubRunnerLogs" }
    
    $Method = "POST"
    $ContentType = "application/json"
    $Resource = "/api/logs"
    $Date = [DateTime]::UtcNow.ToString("r")
    $Body = $LogEntries | ConvertTo-Json -Depth 10
    $BodyBytes = [System.Text.Encoding]::UTF8.GetBytes($Body)
    $ContentLength = $BodyBytes.Length
    
    # Create authorization signature
    $StringToHash = $Method + "`n" + $ContentLength + "`n" + $ContentType + "`n" + "x-ms-date:" + $Date + "`n" + $Resource
    $BytesToHash = [Text.Encoding]::UTF8.GetBytes($StringToHash)
    $KeyBytes = [Convert]::FromBase64String($SharedKey)
    $HMAC = New-Object System.Security.Cryptography.HMACSHA256
    $HMAC.Key = $KeyBytes
    $CalculatedHash = $HMAC.ComputeHash($BytesToHash)
    $EncodedHash = [Convert]::ToBase64String($CalculatedHash)
    $Authorization = 'SharedKey {0}:{1}' -f $WorkspaceId, $EncodedHash
    
    # Create headers
    $Headers = @{
        "Authorization" = $Authorization
        "Log-Type" = $LogType
        "x-ms-date" = $Date
        "time-generated-field" = "TimeGenerated"
    }
    
    # Send to Azure Monitor with retry logic
    $Uri = "https://" + $WorkspaceId + ".ods.opinsights.azure.com" + $Resource + "?api-version=2016-04-01"
    $RetryCount = if ($Config.azureMonitor.retryCount) { $Config.azureMonitor.retryCount } else { 3 }
    $RetryDelay = if ($Config.azureMonitor.retryDelay) { $Config.azureMonitor.retryDelay } else { 5 }
    
    for ($i = 0; $i -lt $RetryCount; $i++) {
        try {
            $Response = Invoke-RestMethod -Uri $Uri -Method $Method -ContentType $ContentType -Headers $Headers -Body $Body -TimeoutSec 30
            break
        }
        catch {
            if ($i -eq ($RetryCount - 1)) {
                throw "Failed to send data to Azure Monitor after $RetryCount retries: $($_.Exception.Message)"
            }
            Start-Sleep -Seconds $RetryDelay
        }
    }
}

# Function to flush any remaining batched logs
function Flush-LogBatch {
    if ($Global:LogBatch.Count -gt 0) {
        $ConfigFile = "$PSScriptRoot\..\..\configs\azure-monitor-config.json"
        if (Test-Path $ConfigFile) {
            $Config = Get-Content $ConfigFile | ConvertFrom-Json -AsHashtable
            Send-ToAzureMonitorBatch -LogEntries $Global:LogBatch -Config $Config
            $Global:LogBatch = @()
        }
    }
}

# Performance tracking wrapper
function Measure-LoggedOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,
        
        [Parameter(Mandatory = $true)]
        [string]$OperationName,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Properties = @{},
        
        [Parameter(Mandatory = $false)]
        [string]$Component = "GitHubRunner"
    )
    
    $OperationId = [System.Guid]::NewGuid().ToString()
    $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    
    Write-LogEnhanced -Message "Starting operation: $OperationName" -Level "Info" -Component $Component -OperationId $OperationId -EventName "OperationStart" -CustomProperties $Properties
    
    try {
        $Result = & $ScriptBlock
        $Stopwatch.Stop()
        
        Write-LogEnhanced -Message "Completed operation: $OperationName" -Level "Success" -Component $Component -OperationId $OperationId -EventName "OperationComplete" -Duration $Stopwatch.ElapsedMilliseconds -CustomProperties $Properties -Metrics @{
            "OperationDurationMs" = $Stopwatch.ElapsedMilliseconds
            "OperationSuccess" = 1
        }
        
        return $Result
    }
    catch {
        $Stopwatch.Stop()
        
        Write-LogEnhanced -Message "Failed operation: $OperationName - Error: $($_.Exception.Message)" -Level "Error" -Component $Component -OperationId $OperationId -EventName "OperationFailed" -Duration $Stopwatch.ElapsedMilliseconds -CustomProperties ($Properties + @{ ErrorDetails = $_.Exception.Message }) -Metrics @{
            "OperationDurationMs" = $Stopwatch.ElapsedMilliseconds
            "OperationSuccess" = 0
        }
        
        throw
    }
}

# Register cleanup on module removal
Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action { Flush-LogBatch }
