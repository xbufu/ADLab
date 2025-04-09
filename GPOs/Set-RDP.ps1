Function Set-RDP {

    <#
        .SYNOPSIS
            Enables RDP.

        .DESCRIPTION
            The function first enables the RDP service and NLA via GPO, then configures the appropriate firewall rules to allow the incoming traffic.

        .PARAMETER GPOName
            The name of the new GPO.

        .PARAMETER TargetOU
            The DistinguishedName (DN) of the OU where the GPO should be linked.
            If not provided, the function defaults to the base domain OU.

        .EXAMPLE
            PS > Set-RDP -Verbose

            Enable RDP using the default GPO name ("Enable RDP") and base domain OU.

        .EXAMPLE
            PS > Set-RDP -GPOName "Enable Remote Desktop" -TargetOU "OU=Workstations,DC=example,DC=com" -Verbose

            Enable RDP with a custom GPO name and target OU.
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false, HelpMessage="The name of the new GPO.")]
        [String]$GPOName = "Enable RDP",

        [Parameter(Mandatory=$false, HelpMessage="DN of the OU where the GPO is linked. Defaults to the root domain if not specified.")]
        [String]$TargetOU
    )

    Import-Module GroupPolicy -Verbose:$false

    # Abfrage der Domäneninformationen
    $Domain = Get-ADDomain
    $Forest = $Domain.Forest
    $DN = $Domain.DistinguishedName

    # Falls kein TargetOU angegeben ist, default auf den Root-DN der Domäne
    if (-not $TargetOU) {
        $TargetOU = $DN
        Write-Verbose "No TargetOU provided. Defaulting to base domain OU: $TargetOU"
    }

    Write-Verbose "Creating GPO..."
    New-GPO -Name $GPOName | Out-Null

    Write-Verbose "Configuring RDP service..."

    $Params = @{
        Name = $GPOName;
        Key  = 'HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server';
    }

    try {
        Set-GPRegistryValue @Params -ValueName 'fDenyTSConnections' -Value 0 -Type DWord | Out-Null
    } catch { 
        Write-Error "Error while configuring RDP policy!"
    }

    $Params = @{
        Name = $GPOName;
        Key  = 'HKLM\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp';
    }

    try {
        Set-GPRegistryValue @Params -ValueName 'UserAuthentication' -Value 1 -Type DWord | Out-Null
    } catch { 
        Write-Error "Error while configuring NLA policy!"
    }

    Write-Verbose "Configuring Firewall rules..."

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
