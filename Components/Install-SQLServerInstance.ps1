function Install-SQLServerInstance {
    <#
        .SYNOPSIS

            Install SQL Server datbase engine, SQL Server Analysis Services, SQL Server Integration Services, and SQL Server tools. Also installs SQL Server Management Studio (SSMS) and the SqlServer PowerShell module.

        .Description

            The function begins by mounting and extracting the supplied ISO images. It then sets up a configuration file for the SQL Server installation. It then installs the defined components in the configuration file in unattended mode. Next, it install SQL Server Management Studio (SSMS) and the SqlServer PowerShell module. Also installs the NuGet package provider, if it's not installed already.

        .PARAMETER SQLServerISOFile

            The absolute path of the setup.exe file for SQL Server.

        .PARAMETER SQLServerISOFolder

            The absolute path to where the ISO will be extracted.
            
        .PARAMETER SSMSSetupFile

            The absolute path of the SSMS setup file.

        .PARAMETER InstanceName

            The name of the new SQL instance.

        .PARAMETER ServiceAccountName

            The name of the service account running the SQL service (for xp_cmdshell).

        .PARAMETER ServiceAccountPassword

            The password of the service account running the SQL service (for xp_cmdshell).

        .PARAMETER SysAdminAccountNames

            The names of the new SQL SysAdmin accounts.

        .PARAMETER SAAccountPassword

            The password of SA account.
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true, HelpMessage="The absolute path of the setup.exe file for SQL Server.")]
        [String]$SQLServerISOFile,

        [Parameter(Mandatory=$false, HelpMessage="The absolute path to where the ISO will be extracted.")]
        [String]$SQLServerISOFolder = "$HOME\SQLServerISO",

        [Parameter(Mandatory=$true, HelpMessage="The absolute path of the SSMS setup file.")]
        [String]$SSMSSetupFile,

        [Parameter(Mandatory=$true, HelpMessage="The name of the new SQL instance.")]
        [String]$InstanceName,

        [Parameter(Mandatory=$true, HelpMessage="The name of the service account running the SQL service (for xp_cmdshell).")]
        [String]$ServiceAccountName,

        [Parameter(Mandatory=$true, HelpMessage="The password of the service account running the SQL service (for xp_cmdshell).")]
        [String]$ServiceAccountPassword,

        [Parameter(Mandatory=$true, HelpMessage="The names of the new SQL SysAdmin accounts.")]
        [Array]$SysAdminAccountNames,

        [Parameter(Mandatory=$false, HelpMessage="The password of SA account.")]
        [String]$SAAccountPassword = "Password!"
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

    Write-Verbose "Preparing config file from template..."

    $ConfigFile = "$SQLServerISOFolder\ConfigurationFile.ini"
    $ConfigFileContent = $ConfigFileTemplate

    Write-Verbose "Setting instance name..."

    $ConfigFileContent = $ConfigFileContent -Replace "SQLINSTANCENAME", "$InstanceName"

    Write-Verbose "Setting service account names..."

    $ConfigFileContent = $ConfigFileContent -Replace "SQLSERVICEACCOUNTNAME", "$ServiceAccountName"
    $ConfigFileContent = $ConfigFileContent -Replace "SQLSERVICEACCOUNTPASSWORD", "$ServiceAccountPassword"

    Write-Verbose "Setting sysadmin account names..."

    $QuotedNames = @()
    foreach($AccountName in $SysAdminAccountNames) {
        $QuotedNames += "`"$AccountName`""
    }

    $SysAdmins = $QuotedNames -Join " "

    $ConfigFileContent = $ConfigFileContent -Replace "SQLSYSADMINACCOUNTNAMES", $SysAdmins

    Write-Verbose "Setting SA account password..."

    $ConfigFileContent = $ConfigFileContent -Replace "SAACCOUNTPASSWORD", "$SAAccountPassword"

    Write-Verbose "Saving configuration file to $ConfigFile..."

    Set-Content -Path $ConfigFile -Value $ConfigFileContent

    Write-Verbose "Installing SQL Server..."

    Start-Process -Wait -FilePath "$SQLServerISOFolder\setup.exe" -ArgumentList "/ConfigurationFile=$($ConfigFile)" -WorkingDirectory $SQLServerISOFolder

    Write-Verbose "Installing SSMS..."

    Start-Process -Wait -FilePath $SSMSSetupFile -ArgumentList @("/Quiet", 'SSMSInstallRoot="C:\Program Files (x86)\SSMS"') -WorkingDirectory (Split-Path -Parent $SSMSSetupFile)

    try {
        Get-PackageProvider -ListAvailable -Name "NuGet"
    } catch {
        Write-Verbose "Installing NuGet..."
        Find-PackageProvider -Name "NuGet" -Force
    }

    if(! (Get-Module -ListAvailable -Name "SqlServer")) {
        Write-Verbose "Installing SqlServer PowerShell module..."
        Install-Module -Name "SqlServer" -Force
    }

    Write-Verbose "Creating Firewall Rules..."

    New-NetFirewallRule -DisplayName "SQL Server Instance" -Direction Inbound -LocalPort 1433 -Protocol TCP -Action Allow | Out-Null
    New-NetFirewallRule -DisplayName "SQL Server Browser Service" -Direction Inbound -LocalPort 1434 -Protocol UDP -Action Allow | Out-Null

    Write-Verbose "Cleaning up setup files..."

    Remove-Item -Recurse -Force -Path $SQLServerISOFolder
}

$ConfigFileTemplate = ';SQL Server 2019 Configuration File
[OPTIONS]

; Accept SQL Server License Terms

IACCEPTSQLSERVERLICENSETERMS="True"

; By specifying this parameter and accepting Microsoft Python Open and Microsoft Python Server terms, you acknowledge that you have read and understood the terms of use. 

IACCEPTPYTHONLICENSETERMS="True"

; Specifies a Setup work flow, like INSTALL, UNINSTALL, or UPGRADE. This is a required parameter. 

ACTION="Install"

; By specifying this parameter and accepting Microsoft R Open and Microsoft R Server terms, you acknowledge that you have read and understood the terms of use. 

IACCEPTROPENLICENSETERMS="True"

; Specifies that SQL Server Setup should not display the privacy statement when ran from the command line. 

SUPPRESSPRIVACYSTATEMENTNOTICE="True"

; Use the /ENU parameter to install the English version of SQL Server on your localized Windows operating system. 

ENU="True"

; Setup will not display any user interface. 

QUIET="True"

; Setup will display progress only, without any user interaction. 

QUIETSIMPLE="False"

; Specifies that the detailed Setup log should be piped to the console. 

INDICATEPROGRESS="False"

; Parameter that controls the user interface behavior. Valid values are Normal for the full UI,AutoAdvance for a simplied UI, and EnableUIOnServerCore for bypassing Server Core setup GUI block. 

; UIMODE="Normal"

; Specify whether SQL Server Setup should discover and include product updates. The valid values are True and False or 1 and 0. By default SQL Server Setup will include updates that are found. 

UpdateEnabled="False"

; If this parameter is provided, then this computer will use Microsoft Update to check for updates. 

USEMICROSOFTUPDATE="True"

; Specifies that SQL Server Setup should not display the paid edition notice when ran from the command line. 

SUPPRESSPAIDEDITIONNOTICE="False"

; Specify the location where SQL Server Setup will obtain product updates. The valid values are "MU" to search Microsoft Update, a valid folder path, a relative path such as .\MyUpdates or a UNC share. By default SQL Server Setup will search Microsoft Update or a Windows Update service through the Window Server Update Services. 

UpdateSource="MU"

; Specifies features to install, uninstall, or upgrade. The list of top-level features include SQL, AS, IS, MDS, and Tools. The SQL feature will install the Database Engine, Replication, Full-Text, and Data Quality Services (DQS) server. The Tools feature will install shared components. 

FEATURES=SQL,AS,IS,Tools

; Displays the command line parameters usage. 

HELP="False"

; Specifies that Setup should install into WOW64. This command line argument is not supported on an IA64 or a 32-bit system. 

X86="False"

; Specify a default or named instance. MSSQLSERVER is the default instance for non-Express editions and SQLExpress for Express editions. This parameter is required when installing the SQL Server Database Engine (SQL), or Analysis Services (AS). 

INSTANCENAME="SQLINSTANCENAME"

; Specify the root installation directory for shared components.  This directory remains unchanged after shared components are already installed. 

INSTALLSHAREDDIR="C:\Program Files\Microsoft SQL Server"

; Specify the root installation directory for the WOW64 shared components.  This directory remains unchanged after WOW64 shared components are already installed. 

INSTALLSHAREDWOWDIR="C:\Program Files (x86)\Microsoft SQL Server"

; Specify the Instance ID for the SQL Server features you have specified. SQL Server directory structure, registry structure, and service names will incorporate the instance ID of the SQL Server instance. 

INSTANCEID="SQLINSTANCENAME"

; Account for SQL Server CEIP service: Domain\User or system account. 

SQLTELSVCACCT="NT Service\SQLTELEMETRY$SQLINSTANCENAME"

; Startup type for the SQL Server CEIP service. 

SQLTELSVCSTARTUPTYPE="Automatic"

; Startup type for the SQL Server Analysis Services CEIP service. 

ASTELSVCSTARTUPTYPE="Automatic"

; Account for SQL Server Analysis Services CEIP service: Domain\User or system account. 

ASTELSVCACCT="NT Service\SSASTELEMETRY$SQLINSTANCENAME"

; Startup type for the SQL Server Integration Services CEIP service. 

ISTELSVCSTARTUPTYPE="Automatic"

; Account for SQL Server Integration Services CEIP service: Domain\User or system account. 

ISTELSVCACCT="NT Service\SSISTELEMETRY150"

; Specify the installation directory. 

INSTANCEDIR="C:\Program Files\Microsoft SQL Server"

; Agent account name 

AGTSVCACCOUNT="NT Service\SQLAgent$SQLINSTANCENAME"

; Auto-start service after installation.  

AGTSVCSTARTUPTYPE="Manual"

; Startup type for Integration Services. 

ISSVCSTARTUPTYPE="Automatic"

; Account for Integration Services: Domain\User or system account. 

ISSVCACCOUNT="NT Service\MsDtsServer150"

; The name of the account that the Analysis Services service runs under. 

ASSVCACCOUNT="NT Service\MSOLAP$SQLINSTANCENAME"

; Controls the service startup type setting after the service has been created. 

ASSVCSTARTUPTYPE="Automatic"

; The collation to be used by Analysis Services. 

ASCOLLATION="Latin1_General_CI_AS"

; The location for the Analysis Services data files. 

ASDATADIR="C:\Program Files\Microsoft SQL Server\MSAS15.SQLINSTANCENAME\OLAP\Data"

; The location for the Analysis Services log files. 

ASLOGDIR="C:\Program Files\Microsoft SQL Server\MSAS15.SQLINSTANCENAME\OLAP\Log"

; The location for the Analysis Services backup files. 

ASBACKUPDIR="C:\Program Files\Microsoft SQL Server\MSAS15.SQLINSTANCENAME\OLAP\Backup"

; The location for the Analysis Services temporary files. 

ASTEMPDIR="C:\Program Files\Microsoft SQL Server\MSAS15.SQLINSTANCENAME\OLAP\Temp"

; The location for the Analysis Services configuration files. 

ASCONFIGDIR="C:\Program Files\Microsoft SQL Server\MSAS15.SQLINSTANCENAME\OLAP\Config"

; Specifies whether or not the MSOLAP provider is allowed to run in process. 

ASPROVIDERMSOLAP="1"

; Specifies the list of administrator accounts that need to be provisioned. 

ASSYSADMINACCOUNTS=SQLSYSADMINACCOUNTNAMES

; Specifies the server mode of the Analysis Services instance. Valid values are MULTIDIMENSIONAL and TABULAR. The default value is TABULAR. 

ASSERVERMODE="TABULAR"

; CM brick TCP communication port 

COMMFABRICPORT="0"

; How matrix will use private networks 

COMMFABRICNETWORKLEVEL="0"

; How inter brick communication will be protected 

COMMFABRICENCRYPTION="0"

; TCP port used by the CM brick 

MATRIXCMBRICKCOMMPORT="0"

; Startup type for the SQL Server service. 

SQLSVCSTARTUPTYPE="Automatic"

; Level to enable FILESTREAM feature at (0, 1, 2 or 3). 

FILESTREAMLEVEL="0"

; The max degree of parallelism (MAXDOP) server configuration option. 

SQLMAXDOP="1"

; Set to "1" to enable RANU for SQL Server Express. 

ENABLERANU="False"

; Specifies a Windows collation or an SQL collation to use for the Database Engine. 

SQLCOLLATION="Latin1_General_CI_AS"

; Account for SQL Server service: Domain\User or system account. 

SQLSVCACCOUNT="SQLSERVICEACCOUNTNAME"
SQLSVCPASSWORD="SQLSERVICEACCOUNTPASSWORD"

; Set to "True" to enable instant file initialization for SQL Server service. If enabled, Setup will grant Perform Volume Maintenance Task privilege to the Database Engine Service SID. This may lead to information disclosure as it could allow deleted content to be accessed by an unauthorized principal. 

SQLSVCINSTANTFILEINIT="False"

; Windows account(s) to provision as SQL Server system administrators. 

SQLSYSADMINACCOUNTS=SQLSYSADMINACCOUNTNAMES

; The default is Windows Authentication. Use "SQL" for Mixed Mode Authentication. 

SECURITYMODE="SQL"

; The number of Database Engine TempDB files. 

SQLTEMPDBFILECOUNT="1"

; Specifies the initial size of a Database Engine TempDB data file in MB. 

SQLTEMPDBFILESIZE="8"

; Specifies the automatic growth increment of each Database Engine TempDB data file in MB. 

SQLTEMPDBFILEGROWTH="64"

; Specifies the initial size of the Database Engine TempDB log file in MB. 

SQLTEMPDBLOGFILESIZE="8"

; Specifies the automatic growth increment of the Database Engine TempDB log file in MB. 

SQLTEMPDBLOGFILEGROWTH="64"

; Provision current user as a Database Engine system administrator for SQL Server 2019 Express. 

ADDCURRENTUSERASSQLADMIN="False"

; Specify 0 to disable or 1 to enable the TCP/IP protocol. 

TCPENABLED="1"

; Specify 0 to disable or 1 to enable the Named Pipes protocol. 

NPENABLED="1"

; Startup type for Browser Service. 

BROWSERSVCSTARTUPTYPE="Automatic"

; Use SQLMAXMEMORY to minimize the risk of the OS experiencing detrimental memory pressure. 

SQLMAXMEMORY="2147483647"

; Use SQLMINMEMORY to reserve a minimum amount of memory available to the SQL Server Memory Manager. 

SQLMINMEMORY="0"

; Password for the SA account
SAPWD="SAACCOUNTPASSWORD"
'
