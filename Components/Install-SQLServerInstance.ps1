function Install-SQLServerInstance {
    <#
        .SYNOPSIS

            Setup a minimal SQL Server 2019 instance. Also installs SQL Server Management Studio (SSMS) and the SqlServer PowerShell module.

        .Description

            The function begins by mounting and extracting the supplied ISO images. It then installs a minimal SQL Server 2019 instance. Next, it install SQL Server Management Studio (SSMS) and the SqlServer PowerShell module. Also installs the NuGet package provider, if it's not installed already. It will then set the TCP port of the instance and create the required firewall rules. Setup requires the computer to be restarted.

        .PARAMETER SQLServerISOFile

            The path of the setup.exe file for SQL Server.
            
        .PARAMETER SSMSSetupFile

            The absolute path of the SSMS setup file.

        .PARAMETER InstanceName

            The name of the new SQL instance.

        .PARAMETER ServiceAccountCredential

            The credential object for the service account (for xp_cmdshell).

        .PARAMETER SysadminAccounts

            The  new SQL Sysadmin accounts.

        .PARAMETER SQLPort

            The TCP port of the SQL instance.

        .PARAMETER SQLServerISOFolder

            The path to where the ISO will be extracted.

        .PARAMETER SQLServerFeatures

            The SQL Server features to install.

        .PARAMETER ShowInstallProgress

            Show SQL Server installation progress.

        .PARAMETER Restart

            Restart Computer after setup finishes.
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true, Position=1, HelpMessage="The path of the setup.exe file for SQL Server.")]
        [String]$SQLServerISOFile,

        [Parameter(Mandatory=$true, Position=2, HelpMessage="The path of the SSMS setup file.")]
        [String]$SSMSSetupFile,

        [Parameter(Mandatory=$true, Position=3, HelpMessage="The name of the new SQL instance.")]
        [String]$InstanceName,

        [Parameter(Mandatory=$true, Position=4, HelpMessage="The credential object for the service account (for xp_cmdshell).")]
        [ValidateNotNull()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $ServiceAccountCredential,

        [Parameter(Mandatory=$false, Position=5, HelpMessage="The names of the Sysadmin accounts.")]
        [Array]$SysadminAccounts = "$($env:USERDOMAIN)\$($env:Username)",

        [Parameter(Mandatory=$false, Position=6, HelpMessage="The TCP port of the SQL instance.")]
        [String]$SQLPort = "1433",

        [Parameter(Mandatory=$false, Position=7, HelpMessage="The absolute path to where the ISO will be extracted.")]
        [String]$SQLServerISOFolder = "$HOME\SQLServerISO",

        [Parameter(Mandatory=$false, Position=8, HelpMessage="The SQL Server features to install.")]
        [String]$SQLServerFeatures = "SQLENGINE,BC,SDK,SNAC_SDK",

        [Parameter(Mandatory=$false, Position=9, HelpMessage="Show SQL Server installation progress.")]
        [Switch]$ShowInstallProgress,

        [Parameter(Mandatory=$false, Position=10, HelpMessage="Restart Computer after setup finishes.")]
        [Switch]$Restart
    )

    Write-Verbose "Checking if session is running with Administrator privileges..."

    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())

    if(! $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Error "Session is not running in elevated context!"
        Return
    }

    Write-Verbose "Extracting files from ISO to $SQLServerISOFolder..."

    New-Item -Path $SQLServerISOFolder -ItemType Directory | Out-Null
    Copy-Item -Path (Join-Path -Path (Get-PSDrive -Name ((Mount-DiskImage -ImagePath $SQLServerISOFile -PassThru) | Get-Volume).DriveLetter).Root -ChildPath '*') -Destination $SQLServerISOFolder -Recurse
    Dismount-DiskImage -ImagePath $SQLServerISOFile | Out-Null

    Write-Verbose "Installing SQL Server..."

    $ServiceAccountName = "$(($ServiceAccountCredential.GetNetworkCredential().Domain).ToUpper())\$($ServiceAccountCredential.GetNetworkCredential().UserName)"
    $ServiceAccountPassword = $ServiceAccountCredential.GetNetworkCredential().Password

    $QuotedNames = @()
    foreach($Account in $SysadminAccounts) {
        $QuotedNames += "`"$Account`""
    }
    $SysadminAccountNames = $QuotedNames -Join " "

    $SetupArguments = @("/Q", "/SUPPRESSPRIVACYSTATEMENTNOTICE", "/IACCEPTSQLSERVERLICENSETERMS", '/ACTION="install"', "/FEATURES=$SQLServerFeatures", "/INSTANCENAME=$InstanceName", "/SQLSVCACCOUNT=`"$ServiceAccountName`"", "/SQLSVCPASSWORD=`"$ServiceAccountPassword`"", "/SQLSYSADMINACCOUNTS=$SysadminAccountNames", "/INDICATEPROGRESS")

    if($ShowInstallProgress) {
        $SetupArguments += "/INDICATEPROGRESS"
    }

    Start-Process -Wait -NoNewWindow -FilePath "$SQLServerISOFolder\setup.exe" -ArgumentList $SetupArguments -WorkingDirectory $SQLServerISOFolder

    Write-Verbose "Installing SSMS..."

    if($SSMSSetupFile.StartsWith("\\")) {
        Copy-Item -Path $SSMSSetupFile -Destination "$SQLServerISOFolder\SSMS_Setup.exe"
        $SSMSSetupFile = "$SQLServerISOFolder\SSMS_Setup.exe"
    }

    Start-Process -Wait -NoNewWindow -FilePath $SSMSSetupFile -ArgumentList @("/Quiet") -WorkingDirectory (Split-Path -Parent $SSMSSetupFile)

    Write-Verbose "Installing NuGet..."

    Find-PackageProvider -Name "NuGet" -Force -Verbose:$false | Out-Null
    
    if(! (Get-Module -ListAvailable -Name "SqlServer")) {
        Write-Verbose "Installing SqlServer PowerShell module..."
       Install-Module -Name "SqlServer" -Force
    }

    Write-Verbose "Setting SQL Port..."

    $Assemblies =   
    "Microsoft.SqlServer.Management.Common",  
    "Microsoft.SqlServer.Smo",  
    "Microsoft.SqlServer.Dmf ",  
    "Microsoft.SqlServer.Instapi ",  
    "Microsoft.SqlServer.SqlWmiManagement ",  
    "Microsoft.SqlServer.ConnectionInfo ",  
    "Microsoft.SqlServer.SmoExtended ",  
    "Microsoft.SqlServer.SqlTDiagM ",  
    "Microsoft.SqlServer.SString ",  
    "Microsoft.SqlServer.Management.RegisteredServers ",  
    "Microsoft.SqlServer.Management.Sdk.Sfc ",  
    "Microsoft.SqlServer.SqlEnum ",  
    "Microsoft.SqlServer.RegSvrEnum ",  
    "Microsoft.SqlServer.WmiEnum ",  
    "Microsoft.SqlServer.ServiceBrokerEnum ",  
    "Microsoft.SqlServer.ConnectionInfoExtended ",  
    "Microsoft.SqlServer.Management.Collector ",  
    "Microsoft.SqlServer.Management.CollectorEnum",  
    "Microsoft.SqlServer.Management.Dac",  
    "Microsoft.SqlServer.Management.DacEnum",  
    "Microsoft.SqlServer.Management.Utility",
    "Microsoft.SqlServer.Management.Smo"
    
    foreach ($Assembly in $Assemblies)  
    {  
        $Assembly = [Reflection.Assembly]::LoadWithPartialName($Assembly)  
    }

    $ComputerName = $env:COMPUTERNAME
    $SMO = 'Microsoft.SqlServer.Management.Smo.'
    $WMI = New-Object ($SMO + 'Wmi.ManagedComputer')

    $URI = "ManagedComputer[@Name='$ComputerName']/ ServerInstance[@Name='$InstanceName']/ServerProtocol[@Name='Tcp']"
    $TCP = $wmi.GetSmoObject($URI)
    foreach ($IPAddress in $TCP.IPAddresses)
    {
        $IPAddress.IPAddressProperties["TcpDynamicPorts"].Value = ""
        $IPAddress.IPAddressProperties["TcpPort"].Value = "$SQLPort"
    }

    $TCP.Alter()

    Restart-Service -Force "MSSQL`$$InstanceName"

    Write-Verbose "Creating Firewall Rules..."

    New-NetFirewallRule -DisplayName "SQL Server Instance" -Direction Inbound -LocalPort $SQLPort -Protocol TCP -Action Allow | Out-Null
    New-NetFirewallRule -DisplayName "SQL Server Browser Service" -Direction Inbound -LocalPort 1434 -Protocol UDP -Action Allow | Out-Null

    Write-Verbose "Cleaning up setup files..."

    Remove-Item -Recurse -Force -Path $SQLServerISOFolder

    if($Restart) {
        Restart-Computer
    } else {
        Write-Warning "Restart computer to finish setup!"
    }
}
