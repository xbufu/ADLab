Function Set-RDP {

    <#
        .SYNOPSIS
            Enables RDP.

        .DESCRIPTION
            The function first enables the RDP service and NLA via GPO, then configures the appropriate firewall rules to allow the incoming traffic.

        .PARAMETER GPOName

            The name of the new GPO.

        .EXAMPLE
            PS > Set-RDP -Verbose

            Enable RDP and display verbose output. Use default GPO name "Enable RDP"

        .EXAMPLE
            PS > Set-RDP -GPOName "Enable Remote Desktop" -Verbose

            Enable RDP with custom GPO name.
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false, HelpMessage="The name of the new GPO.")]
        [String]$GPOName = "Enable RDP"
    )

    Import-Module GroupPolicy -Verbose:$false

    $Domain = Get-ADDomain
    $Forest = $Domain.Forest
    $DN = $Domain.DistinguishedName

    Write-Verbose "Creating GPO..."

    New-GPO -Name $GPOName | Out-Null

    Write-Verbose "Configuring RDP service..."

    $Params = @{
        Name = $GPOName;
        Key = 'HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server';
    }

    try {
        Set-GPRegistryValue @Params -ValueName 'fDenyTSConnections' -Value 0 -Type DWord | Out-Null
    } catch { 
        Write-Error "Error while configuring RDP policy!"
    }

    $Params = @{
        Name = $GPOName;
        Key = 'HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp';
    }

    try {
        Set-GPRegistryValue @Params -ValueName 'UserAuthentication' -Value 1 -Type DWord | Out-Null
    } catch { 
        Write-Error "Error while configuring NLA policy!"
    }

    Write-Verbose "Configuring Firewall rules..."

    $TargetOU = $DN
    $PolicyStoreName = "$Forest\$GPOName"
    $GPOSessionName = Open-NetGPO -PolicyStore $PolicyStoreName

    New-NetFirewallRule -DisplayName "Allow RDP" -Profile Any -Direction Inbound -GPOSession $GPOSessionName -PolicyStore $GPOName -Protocol TCP -LocalPort 3389 | Out-Null

    Save-NetGPO -GPOSession $GPOSessionName

    Write-Verbose "Configuring Security Filter..."

    Set-GPPermissions -Name $GPOName -PermissionLevel GpoApply -TargetName "Domain Computers" -TargetType Group | Out-Null
    Set-GPPermissions -Name $GPOName -PermissionLevel GpoApply -TargetName "Domain Users" -TargetType User | Out-Null

    Write-Verbose "Linking and enabling new GPO..."

    New-GPLink -Name $GPOName -Target $TargetOU -LinkEnabled Yes -Enforced Yes | Out-Null
}
