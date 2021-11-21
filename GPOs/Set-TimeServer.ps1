Function Set-TimeServer {
    
    <#
        .SYNOPSIS
            Set a time server.

        .DESCRIPTION
            The function enables the NTP client and sets the specified time server.

        .PARAMETER Server

            The address and type of the time server.

        .PARAMETER GPOName

            The name of the new GPO.

        .PARAMETER WMIFilterName

            The name of the new WMI filter.

        .EXAMPLE
            PS > Set-TimeServer -Server "172.16.3.1,0x1" -Verbose

            Configure the Time Server and display verbose output.

        .EXAMPLE
            PS > Set-TimeServer -Server "172.16.3.1,0x1" -GPOName "Set Time Server" -WMIFilterName "PDC Filter" -Verbose

            Configure the Time Server with custom GPO name and custom WMI filter name.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true, Position=0, HelpMessage="The address and type of the time server.")]
        [String]$Server,

        [Parameter(Mandatory=$false, Position=1, HelpMessage="The name of the new GPO.")]
        [String]$GPOName = "Set Time Server",

        [Parameter(Mandatory=$false, Position=2, HelpMessage="The name of the new WMI filter.")]
        [String]$WMIFilterName = "Filter PDC Emulators"
    )

    Import-Module GroupPolicy -Verbose:$false

    $Domain = Get-ADDomain
    $Forest = $Domain.Forest
    $DN = $Domain.DistinguishedName
    $TargetOU = "OU=Domain Controllers,$DN"

    Write-Verbose "Creating GPO..."

    New-GPO -Name $GPOName | Out-Null

    Write-Verbose "Configuring the NTP Client..."

    $Params = @{
        Name = $GPOName;
        Key = 'HKLM\Software\Policies\Microsoft\W32time\TimeProviders\NTPClient';
    }

    try {
        Set-GPRegistryValue @Params -ValueName "Enabled" -Value 1 -Type DWORD | Out-Null
        Set-GPRegistryValue @Params -ValueName "EventLogFlags" -Value 0 -Type DWORD | Out-Null
        Set-GPRegistryValue @Params -ValueName "SpecialPollInterval" -Value 3600 -Type DWORD | Out-Null
        Set-GPRegistryValue @Params -ValueName "ResolvePeerBackoffMaxTimes" -Value 7 -Type DWORD | Out-Null
        Set-GPRegistryValue @Params -ValueName "ResolvePeerBackoffMinutes" -Value 15 -Type DWORD | Out-Null
        Set-GPRegistryValue @Params -ValueName "CrossSiteSyncFlags" -Value 2 -Type DWORD | Out-Null
    } catch {
        Write-Error "Error while configuring the NTP Client policy!"
    }

    Write-Verbose "Enabling NTP Server..."

    $Params = @{
        Name = $GPOName;
        Key = 'HKLM\Software\Policies\Microsoft\w32time\TimeProviders\NtpServer';
    }

    try {
        Set-GPRegistryValue @Params -ValueName "Enabled" -Value 1 -Type DWORD | Out-Null
    } catch {
        Write-Error "Error while configuring the Enable NTP Server policy!"
    }

    Write-Verbose "Configuring the NTP Server..."

    $Params = @{
        Name = $GPOName;
        Key = 'HKLM\Software\Policies\Microsoft\W32time\Parameters';
    }

    try {
        Set-GPRegistryValue @Params -ValueName "Type" -Value "NTP" -Type String | Out-Null
        Set-GPRegistryValue @Params -ValueName "NtpServer" -Value $Server -Type String | Out-Null
    } catch {
        Write-Error "Error while configuring the NTP Server policy!"
    }

    Write-Verbose "Configuring Firewall Rules..."

    $PolicyStoreName = "$Forest\$GPOName"
    $GPOSessionName = Open-NetGPO -PolicyStore $PolicyStoreName

    New-NetFirewallRule -DisplayName "Allow NTP" -Profile Any -Direction Outbound -GPOSession $GPOSessionName -PolicyStore $GPOName -Protocol UDP -LocalPort 123 | Out-Null

    Save-NetGPO -GPOSession $GPOSessionName

    Write-Verbose "Configuring Security Filter..."

    $DC = (Get-ADDomainController).Name
    $DCMachineAccount = "$DC$"

    Set-GPPermissions -Name $GPOName -PermissionLevel GpoApply -TargetName $DCMachineAccount -TargetType Group | Out-Null

    Write-Verbose "Creating WMI Filter..."

    Import-Module ".\New-GPWmiFilter.ps1" -Verbose:$false

    New-GPWmiFilter -Name $WMIFilterName -Expression "SELECT * FROM Win32_ComputerSystem WHERE DomainRole = 5" -Description "Only apply to PDC Emulators."

    Write-Verbose "Applying WMI Filter to GPO..."

    $GPdomain = New-Object Microsoft.GroupPolicy.GPDomain
    $SearchFilter = New-Object Microsoft.GroupPolicy.GPSearchCriteria
    $WMIFilter = $GPdomain.SearchWmiFilters($SearchFilter) | ?{ $_.Name -eq $WMIFilterName }
    $GPO = Get-Gpo -Name $GPOName
    $GPO.WmiFilter = $WMIFilter

    Write-Verbose "Linking and enabling new GPO..."

    New-GPLink -Name $GPOName -Target $TargetOU -LinkEnabled Yes -Enforced Yes | Out-Null
}
