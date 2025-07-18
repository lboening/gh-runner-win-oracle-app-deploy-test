# Deploy-ThirdPartyApplication.ps1
# Downloads and installs third-party applications from Azure Blob Storage

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$StorageAccountName,
    
    [Parameter(Mandatory = $true)]
    [string]$ContainerName,
    
    [Parameter(Mandatory = $true)]
    [string]$BlobName,
    
    [Parameter(Mandatory = $false)]
    [string]$DownloadPath = "C:\Temp\$BlobName",
    
    [Parameter(Mandatory = $false)]
    [string]$AccessKey,
    
    [Parameter(Mandatory = $false)]
    [string]$SasToken,
    
    [Parameter(Mandatory = $false)]
    [hashtable]$InstallParameters = @{},
    
    [Parameter(Mandatory = $false)]
    [string]$LogPath = "C:\Logs\ApplicationDeployment.log"
)

# Import utilities
. "$PSScriptRoot\..\utilities\Write-Log.ps1"

function Deploy-ThirdPartyApplication {
    Write-Log "Starting third-party application deployment process..." -Level "Info"
    
    try {
        # Install Azure PowerShell modules if not present
        if (!(Get-Module -Name Az.Storage -ListAvailable)) {
            Write-Log "Installing Azure Storage module..." -Level "Info"
            Install-Module -Name Az.Storage -Force -Scope CurrentUser
        }
        
        # Create download directory
        $DownloadDir = Split-Path $DownloadPath -Parent
        if (!(Test-Path $DownloadDir)) {
            New-Item -Path $DownloadDir -ItemType Directory -Force | Out-Null
            Write-Log "Created download directory: $DownloadDir" -Level "Info"
        }
        
        # Authenticate to Azure Storage
        $StorageContext = $null
        if ($AccessKey) {
            Write-Log "Authenticating with Storage Account Key..." -Level "Info"
            $StorageContext = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $AccessKey
        }
        elseif ($SasToken) {
            Write-Log "Authenticating with SAS Token..." -Level "Info"
            $StorageContext = New-AzStorageContext -StorageAccountName $StorageAccountName -SasToken $SasToken
        }
        else {
            Write-Log "Attempting to authenticate with Managed Identity..." -Level "Info"
            Connect-AzAccount -Identity -ErrorAction Stop
            $StorageAccount = Get-AzStorageAccount | Where-Object { $_.StorageAccountName -eq $StorageAccountName }
            $StorageContext = $StorageAccount.Context
        }
        
        # Download the application package
        Write-Log "Downloading $BlobName from $StorageAccountName/$ContainerName..." -Level "Info"
        Get-AzStorageBlobContent -Container $ContainerName -Blob $BlobName -Destination $DownloadPath -Context $StorageContext -Force
        
        if (!(Test-Path $DownloadPath)) {
            throw "Download failed - file not found at $DownloadPath"
        }
        
        Write-Log "Download completed successfully: $DownloadPath" -Level "Success"
        
        # Extract if it's a zip file
        if ($DownloadPath -like "*.zip") {
            $ExtractPath = Join-Path $DownloadDir "extracted"
            Write-Log "Extracting archive to: $ExtractPath" -Level "Info"
            Expand-Archive -Path $DownloadPath -DestinationPath $ExtractPath -Force
            
            # Find installer files
            $Installers = @()
            $Installers += Get-ChildItem -Path $ExtractPath -Filter "*.msi" -Recurse
            $Installers += Get-ChildItem -Path $ExtractPath -Filter "setup.exe" -Recurse
            $Installers += Get-ChildItem -Path $ExtractPath -Filter "install.exe" -Recurse
            
            if ($Installers.Count -eq 0) {
                throw "No installer files found in the extracted archive"
            }
            
            # Run installation for each installer
            foreach ($Installer in $Installers) {
                Install-Application -InstallerPath $Installer.FullName -Parameters $InstallParameters
            }
        }
        else {
            # Direct installer file
            Install-Application -InstallerPath $DownloadPath -Parameters $InstallParameters
        }
        
        Write-Log "Third-party application deployment completed successfully!" -Level "Success"
    }
    catch {
        Write-Log "Application deployment failed: $($_.Exception.Message)" -Level "Error"
        throw
    }
}

function Install-Application {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstallerPath,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Parameters = @{}
    )
    
    $InstallerFile = Get-Item $InstallerPath
    $LogFile = Join-Path $env:TEMP "install_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
    
    Write-Log "Installing application: $($InstallerFile.Name)" -Level "Info"
    Write-Log "Installation log: $LogFile" -Level "Info"
    
    switch ($InstallerFile.Extension.ToLower()) {
        ".msi" {
            # MSI Installation
            $MsiArguments = @(
                "/i", "`"$InstallerPath`"", "/quiet", "/norestart", "/l*v", "`"$LogFile`""
            )
            
            # Add custom parameters
            foreach ($Key in $Parameters.Keys) {
                $MsiArguments += "$Key=$($Parameters[$Key])"
            }
            
            Write-Log "Running MSIEXEC with arguments: $($MsiArguments -join ' ')" -Level "Info"
            $Process = Start-Process -FilePath "msiexec.exe" -ArgumentList $MsiArguments -Wait -PassThru
            
            if ($Process.ExitCode -eq 0) {
                Write-Log "MSI installation completed successfully" -Level "Success"
            }
            elseif ($Process.ExitCode -eq 3010) {
                Write-Log "MSI installation completed successfully (reboot required)" -Level "Warning"
            }
            else {
                throw "MSI installation failed with exit code: $($Process.ExitCode)"
            }
        }
        
        ".exe" {
            # EXE Installation
            $ExeArguments = @()
            
            # Add silent install parameters
            if ($Parameters.ContainsKey("Silent")) {
                $ExeArguments += $Parameters["Silent"]
            }
            else {
                $ExeArguments += "/SILENT"
            }
            
            if ($Parameters.ContainsKey("NoRestart")) {
                $ExeArguments += $Parameters["NoRestart"]
            }
            else {
                $ExeArguments += "/NORESTART"
            }
            
            # Add custom parameters
            foreach ($Key in $Parameters.Keys) {
                if ($Key -notin @("Silent", "NoRestart")) {
                    $ExeArguments += "$Key=$($Parameters[$Key])"
                }
            }
            
            Write-Log "Running EXE with arguments: $($ExeArguments -join ' ')" -Level "Info"
            $Process = Start-Process -FilePath $InstallerPath -ArgumentList $ExeArguments -Wait -PassThru
            
            if ($Process.ExitCode -eq 0) {
                Write-Log "EXE installation completed successfully" -Level "Success"
            }
            else {
                Write-Log "EXE installation completed with exit code: $($Process.ExitCode)" -Level "Warning"
            }
        }
        
        default {
            throw "Unsupported installer type: $($InstallerFile.Extension)"
        }
    }
}

# Execute main function
Deploy-ThirdPartyApplication
