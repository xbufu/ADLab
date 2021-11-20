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

        .EXAMPLE
            PS > Set-TimeServer -Server "172.16.3.1,0x1" -Verbose

            Configure the Time Server and display verbose output.

        .EXAMPLE
            PS > Set-TimeServer -Server "172.16.3.1,0x1" -GPOName "Power Settings" -Verbose

            Configure the Time Server with custom GPO name.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true, HelpMessage="The address and type of the time server.")]
        [String]$Server,

        [Parameter(Mandatory=$false, HelpMessage="The name of the new GPO.")]
        [String]$GPOName = "Disable Windows Defender"
    )

    Import-Module GroupPolicy -Verbose:$false

    $Domain = Get-ADDomain
    $Forest = $Domain.Forest
    $DN = $Domain.DistinguishedName
    $TargetOU = $DN

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

    Set-GPPermissions -Name $GPOName -PermissionLevel GpoApply -TargetName "Domain Computers" -TargetType Group | Out-Null
    Set-GPPermissions -Name $GPOName -PermissionLevel GpoApply -TargetName "Domain Users" -TargetType User | Out-Null

    Write-Verbose "Linking and enabling new GPO..."

    New-GPLink -Name $GPOName -Target $TargetOU -LinkEnabled Yes -Enforced Yes | Out-Null
}
