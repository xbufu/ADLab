Function Set-SMB {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false)]
        [String]$GPOName = "Enable SMB",

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

    Write-Verbose "Configuring File & Printer Sharing Policy..."
    $Params = @{
        Name = $GPOName;
        Key  = 'HKLM\SOFTWARE\Policies\Microsoft\WindowsFirewall\StandardProfile\Services\FileAndPrint';
    }
    try {
        Set-GPRegistryValue @Params -ValueName 'Enabled' -Value 1 -Type DWord | Out-Null
        Set-GPRegistryValue @Params -ValueName 'RemoteAddresses' -Value "*" -Type String | Out-Null
    } catch {
        Write-Error "Error while configuring File & Printer Sharing Policy!"
    }

    Write-Verbose "Configuring Network Discovery Policy..."
    $Params = @{
        Name = $GPOName;
        Key  = 'HKLM\Software\Policies\Microsoft\Windows\LLTD';
    }
    try {
        Set-GPRegistryValue @Params -ValueName 'EnableLLTDIO' -Value 1 -Type DWord | Out-Null
        Set-GPRegistryValue @Params -ValueName 'AllowLLTDIOOnDomain' -Value 1 -Type DWord | Out-Null
        Set-GPRegistryValue @Params -ValueName 'AllowLLTDIOOnPublicNet' -Value 1 -Type DWord | Out-Null
        Set-GPRegistryValue @Params -ValueName 'ProhibitLLTDIOOnPrivateNet' -Value 0 -Type DWord | Out-Null
        Set-GPRegistryValue @Params -ValueName 'EnableRspndr' -Value 1 -Type DWord | Out-Null
        Set-GPRegistryValue @Params -ValueName 'AllowRspndrOnDomain' -Value 1 -Type DWord | Out-Null
        Set-GPRegistryValue @Params -ValueName 'AllowRspndrOnPublicNet' -Value 1 -Type DWord | Out-Null
        Set-GPRegistryValue @Params -ValueName 'ProhibitRspndrOnPrivateNet' -Value 0 -Type DWord | Out-Null
    } catch {
        Write-Error "Error while configuring Network Discovery Policy!"
    }

    Write-Verbose "Configuring Firewall rules..."
    $PolicyStoreName = "$Forest\$GPOName"
    $GPOSessionName = Open-NetGPO -PolicyStore $PolicyStoreName

    Write-Verbose "Creating Firewall Rules for File & Printer Sharing..."
    New-NetFirewallRule -DisplayName "File and Printer Sharing (LLMNR-UDP-IN)" -Profile Any -Program "%SystemRoot%\system32\svchost.exe" -Service "dnscache" -Direction Inbound -GPOSession $GPOSessionName -PolicyStore $GPOName -Protocol UDP -LocalPort 5355 | Out-Null
    New-NetFirewallRule -DisplayName "File and Printer Sharing (Echo Request - ICMPv6-In)" -Profile Any -Program "System" -Direction Inbound -GPOSession $GPOSessionName -PolicyStore $GPOName -Protocol ICMPv6 -LocalPort Any | Out-Null
    New-NetFirewallRule -DisplayName "File and Printer Sharing (Echo Request - ICMPv4-In)" -Profile Any -Program "System" -Direction Inbound -GPOSession $GPOSessionName -PolicyStore $GPOName -Protocol ICMPv4 -LocalPort Any | Out-Null
    New-NetFirewallRule -DisplayName "File and Printer Sharing (Spooler Service - RPC-EPMAP)" -Profile Any -Program "%SystemRoot%\system32\svchost.exe" -Service "Rpcss" -Direction Inbound -GPOSession $GPOSessionName -PolicyStore $GPOName -Protocol TCP -LocalPort "RPCEPMap" | Out-Null
    New-NetFirewallRule -DisplayName "File and Printer Sharing (Spooler Service - RPC)" -Profile Any -Direction Inbound -Program "%SystemRoot%\system32\spoolsv.exe" -Service "Spooler" -GPOSession $GPOSessionName -PolicyStore $GPOName -Protocol TCP -LocalPort "RPC" | Out-Null
    New-NetFirewallRule -DisplayName "File and Printer Sharing (NB-Datagram-In)" -Profile Any -Program "System" -Direction Inbound -GPOSession $GPOSessionName -PolicyStore $GPOName -Protocol UDP -LocalPort 138 | Out-Null
    New-NetFirewallRule -DisplayName "File and Printer Sharing (NB-Name-In)" -Profile Any -Program "System" -Direction Inbound -GPOSession $GPOSessionName -PolicyStore $GPOName -Protocol UDP -LocalPort 137 | Out-Null
    New-NetFirewallRule -DisplayName "File and Printer Sharing (SMB-In)" -Profile Any -Program "System" -Direction Inbound -GPOSession $GPOSessionName -PolicyStore $GPOName -Protocol TCP -LocalPort 445 | Out-Null
    New-NetFirewallRule -DisplayName "File and Printer Sharing (NB-Session-In)" -Profile Any -Program "System" -Direction Inbound -GPOSession $GPOSessionName -PolicyStore $GPOName -Protocol TCP -LocalPort 139 | Out-Null

    Write-Verbose "Creating Firewall Rules for Network Discovery..."
    New-NetFirewallRule -DisplayName "Network Discovery (WSD-In)" -Profile Any -Direction Inbound -Program "%SystemRoot%\system32\dashost.exe" -Service Any -Protocol UDP -LocalPort 3702 -GPOSession $GPOSessionName -PolicyStore $GPOName | Out-Null
    New-NetFirewallRule -DisplayName "Network Discovery (WSD-In)" -Profile Any -Direction Inbound -Program "%SystemRoot%\system32\svchost.exe" -Service "fdphost" -Protocol UDP -LocalPort 3702 -GPOSession $GPOSessionName -PolicyStore $GPOName | Out-Null
    New-NetFirewallRule -DisplayName "Network Discovery (Pub-WSD-In)" -Profile Any -Direction Inbound -Program "%SystemRoot%\system32\svchost.exe" -Service "fdrespub" -Protocol UDP -LocalPort 3702 -GPOSession $GPOSessionName -PolicyStore $GPOName | Out-Null
    New-NetFirewallRule -DisplayName "Network Discovery (WSD-Events-In)" -Profile Any -Direction Inbound -Program "System" -Service Any -Protocol TCP -LocalPort 5357 -GPOSession $GPOSessionName -PolicyStore $GPOName | Out-Null
    New-NetFirewallRule -DisplayName "Network Discovery (WSD EventsSecure-In)" -Profile Any -Direction Inbound -Program "System" -Service Any -Protocol TCP -LocalPort 5358 -GPOSession $GPOSessionName -PolicyStore $GPOName | Out-Null
    New-NetFirewallRule -DisplayName "Network Discovery (LLMNR-UDP-In)" -Profile Any -Direction Inbound -Program "%SystemRoot%\system32\svchost.exe" -Service "dnscache" -Protocol UDP -LocalPort 5355 -GPOSession $GPOSessionName -PolicyStore $GPOName | Out-Null
    New-NetFirewallRule -DisplayName "Network Discovery (NB-Datagram-In)" -Profile Any -Direction Inbound -Program "System" -Service Any -Protocol UDP -LocalPort 138 -GPOSession $GPOSessionName -PolicyStore $GPOName | Out-Null
    New-NetFirewallRule -DisplayName "Network Discovery (NB-Name-In)" -Profile Any -Direction Inbound -Program "System" -Service Any -Protocol UDP -LocalPort 137 -GPOSession $GPOSessionName -PolicyStore $GPOName | Out-Null
    New-NetFirewallRule -DisplayName "Network Discovery (UPnP-In)" -Profile Any -Direction Inbound -Program "System" -Service Any -Protocol TCP -LocalPort 2869 -GPOSession $GPOSessionName -PolicyStore $GPOName | Out-Null
    New-NetFirewallRule -DisplayName "Network Discovery (SSDP-In)" -Profile Any -Direction Inbound -Program "%SystemRoot%\system32\svchost.exe" -Service "Ssdpsrv" -Protocol UDP -LocalPort 1900 -GPOSession $GPOSessionName -PolicyStore $GPOName | Out-Null

    Save-NetGPO -GPOSession $GPOSessionName

    Write-Verbose "Configuring Security Filter..."
    Set-GPPermissions -Name $GPOName -PermissionLevel GpoApply -TargetName "Domain Computers" -TargetType Group | Out-Null
    Set-GPPermissions -Name $GPOName -PermissionLevel GpoApply -TargetName "Domain Users" -TargetType User | Out-Null

    Write-Verbose "Linking and enabling new GPO..."
    New-GPLink -Name $GPOName -Target $TargetOU -LinkEnabled Yes -Enforced Yes | Out-Null
}
