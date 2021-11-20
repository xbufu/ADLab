Function Set-WMI {

    <#
        .SYNOPSIS
            Enables WMI.

        .DESCRIPTION
            The function creates a new GPO containing a firewall rule to allow WMI traffic.

        .PARAMETER GPOName

            The name of the new GPO.

        .EXAMPLE
            PS > Set-WMI -Verbose

            Enable WMI and display verbose output. Use default GPO name "Enable WMI"

        .EXAMPLE
            PS > Set-WMI -GPOName "Enable Windows Management Instrumentation" -Verbose

            Enable WMI with custom GPO name.
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false, HelpMessage="The name of the new GPO.")]
        [String]$GPOName = "Enable WMI"
    )

    Import-Module GroupPolicy -Verbose:$false

    $Domain = Get-ADDomain
    $Forest = $Domain.Forest
    $DN = $Domain.DistinguishedName

    Write-Verbose "Creating GPO..."

    New-GPO -Name $GPOName | Out-Null

    Write-Verbose "Configuring Firewall rules..."

    $TargetOU = $DN
    $PolicyStoreName = "$Forest\$GPOName"
    $GPOSessionName = Open-NetGPO -PolicyStore $PolicyStoreName

    New-NetFirewallRule -DisplayName "Allow WMI (ASync-In)" -Profile Any -Direction Inbound -GPOSession $GPOSessionName -PolicyStore $GPOName -Protocol TCP -LocalPort Any -Program "%systemroot%\system32\wbem\unsecapp.exe" | Out-Null
    New-NetFirewallRule -DisplayName "Allow WMI (DCOM-In)" -Profile Any -Direction Inbound -GPOSession $GPOSessionName -PolicyStore $GPOName -Protocol TCP -LocalPort 135 -Program "%SystemRoot%\system32\svchost.exe" | Out-Null
    New-NetFirewallRule -DisplayName "Allow WMI (WMI-In)" -Profile Any -Direction Inbound -GPOSession $GPOSessionName -PolicyStore $GPOName -Protocol TCP -LocalPort Any -Program "%SystemRoot%\system32\svchost.exe" | Out-Null

    Save-NetGPO -GPOSession $GPOSessionName

    Write-Verbose "Configuring Security Filter..."

    Set-GPPermissions -Name $GPOName -PermissionLevel GpoApply -TargetName "Domain Computers" -TargetType Group | Out-Null
    Set-GPPermissions -Name $GPOName -PermissionLevel GpoApply -TargetName "Domain Users" -TargetType User | Out-Null

    Write-Verbose "Linking and enabling new GPO..."

    New-GPLink -Name $GPOName -Target $TargetOU -LinkEnabled Yes -Enforced Yes | Out-Null
}
