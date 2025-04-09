Function Set-PSRemoting {

    <#
        .SYNOPSIS
            Enables PS Remoting.

        .DESCRIPTION
            The function first configures and enables WinRM via GPO, then adds the appropriate firewall rules to allow incoming traffic.

        .PARAMETER GPOName
            The name of the new GPO.

        .PARAMETER TargetOU
            The DistinguishedName (DN) of the OU where the GPO is linked.
            If not specified, defaults to the domain root.

        .EXAMPLE
            PS > Set-PSRemoting -Verbose

            Enable PS Remoting and display verbose output. Uses default GPO name and base domain OU.

        .EXAMPLE
            PS > Set-PSRemoting -GPOName "Enable PSR" -TargetOU "OU=Workstations,DC=example,DC=com" -Verbose

            Enable PS Remoting with custom GPO name and target OU.
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false, HelpMessage="The name of the new GPO.")]
        [String]$GPOName = "Enable PS Remoting",

        [Parameter(Mandatory=$false, HelpMessage="DN of the OU where the GPO is linked. Defaults to the base domain if not specified.")]
        [String]$TargetOU
    )

    Import-Module GroupPolicy -Verbose:$false

    $Domain = Get-ADDomain
    $Forest = $Domain.Forest
    $DN = $Domain.DistinguishedName

    if (-not $TargetOU) {
        $TargetOU = $DN
        Write-Verbose "No TargetOU provided. Defaulting to base domain OU: $TargetOU"
    }

    Write-Verbose "Creating GPO..."
    New-GPO -Name $GPOName | Out-Null

    Write-Verbose "Configuring PS Remoting policy..."
    $Params = @{
        Name = $GPOName;
        Key  = 'HKLM\Software\Policies\Microsoft\Windows\WinRM\Service';
    }

    try {
        Set-GPRegistryValue @Params -ValueName 'AllowAutoConfig' -Value 1 -Type DWord | Out-Null
        Set-GPRegistryValue @Params -ValueName 'IPv4Filter' -Value '*' -Type String | Out-Null
        Set-GPRegistryValue @Params -ValueName 'IPv6Filter' -Value '*' -Type String | Out-Null
    } catch {
        Write-Error "Error enabling remoting policy"
    }

    Write-Verbose "Configuring WinRM service..."
    $Params = @{
        Name = $GPOName;
        Key  = 'HKLM\SYSTEM\CurrentControlSet\Services\WinRM';
    }

    try {
        Set-GPRegistryValue @Params -ValueName 'Start' -Value 2 -Type DWord | Out-Null
        Set-GPRegistryValue @Params -ValueName 'DelayedAutoStart' -Value 0 -Type DWord | Out-Null
    } catch {
        Write-Error "Error while configuring PS Remoting policy!"
    }

    Write-Verbose "Configuring Firewall rules..."
    $PolicyStoreName = "$Forest\$GPOName"
    $GPOSessionName = Open-NetGPO -PolicyStore $PolicyStoreName
    $FWRuleName = "Allow WinRM"

    New-NetFirewallRule -DisplayName $FWRuleName -Profile Any -Direction Inbound -GPOSession $GPOSessionName -PolicyStore $GPOName -Protocol TCP -LocalPort 5985 | Out-Null
    Save-NetGPO -GPOSession $GPOSessionName | Out-Null

    Write-Verbose "Configuring Security Filter..."
    Set-GPPermissions -Name $GPOName -PermissionLevel GpoApply -TargetName "Domain Computers" -TargetType Group | Out-Null
    Set-GPPermissions -Name $GPOName -PermissionLevel GpoApply -TargetName "Domain Users" -TargetType User | Out-Null

    Write-Verbose "Linking and enabling new GPO..."
    New-GPLink -Name $GPOName -Target $TargetOU -LinkEnabled Yes -Enforced Yes | Out-Null
}
