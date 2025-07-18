# Application Configuration
# Define third-party applications to be deployed from Azure Blob Storage

@{
    # Sample Web Application
    "MyWebApplication" = @{
        StorageAccount = "mycompanystorage"
        Container = "applications"
        BlobName = "MyWebApp_v2.1.zip"
        DownloadPath = "C:\Temp\MyWebApp_v2.1.zip"
        InstallParameters = @{
            "INSTALLDIR" = "C:\inetpub\wwwroot\MyWebApp"
            "WEBSITE_NAME" = "MyWebApp"
            "APP_POOL_NAME" = "MyWebAppPool"
            "SILENT" = "/VERYSILENT"
            "NORESTART" = "/NORESTART"
        }
        PostInstall = @{
            ConfigureIIS = $true
            SiteName = "MyWebApp"
            PhysicalPath = "C:\inetpub\wwwroot\MyWebApp"
            AppPoolName = "MyWebAppPool"
            Port = 8080
            NetFrameworkVersion = "v4.0"
        }
    }
    
    # Database Tools
    "DatabaseTools" = @{
        StorageAccount = "mycompanystorage"
        Container = "tools"
        BlobName = "OracleTools_12.2.msi"
        DownloadPath = "C:\Temp\OracleTools_12.2.msi"
        InstallParameters = @{
            "ORACLE_HOME" = "C:\Oracle\Tools"
            "INSTALLTYPE" = "Complete"
        }
        PostInstall = @{
            ConfigureIIS = $false
        }
    }
    
    # Custom Business Application
    "BusinessApp" = @{
        StorageAccount = "mycompanystorage"
        Container = "applications"
        BlobName = "BusinessApp_setup.exe"
        DownloadPath = "C:\Temp\BusinessApp_setup.exe"
        InstallParameters = @{
            "Silent" = "/S"
            "NoRestart" = "/NoRestart"
            "/DIR" = "C:\Program Files\BusinessApp"
            "/COMPONENTS" = "main,docs,samples"
        }
        PostInstall = @{
            ConfigureIIS = $true
            SiteName = "BusinessApp"
            PhysicalPath = "C:\Program Files\BusinessApp\Web"
            AppPoolName = "BusinessAppPool"
            Port = 9090
            NetFrameworkVersion = "v4.5"
        }
    }
}
