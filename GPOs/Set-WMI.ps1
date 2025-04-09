Function Set-WMI {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [String]$GPOName = "Enable WMI",

        [Parameter(Mandatory=$false)]
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

    Write-Verbose "Configuring Firewall rules..."
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
