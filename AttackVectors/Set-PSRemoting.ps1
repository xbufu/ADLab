function Set-PSRemoting {
    [CmdletBinding()]
    Param()

    Write-Verbose "Configuring GPO policies required for the domain..."
    
    Import-Module GroupPolicy
    $Domain = Get-ADDomain
    $Forest = $Domain.Forest
    $DN = $Domain.DistinguishedName

    $FWRule = "Allow WinRM TCP 5985 To Domain Joined Systems"
    $GPOName = "WinRM Firewall TCP 5985"
    $TargetOU = $DN
    $PolicyStoreName = "$Forest\" + $GPOName
    New-GPO -Name $GPOName | New-Gplink -Target $TargetOU | Out-Null
    $GPOSessionName = Open-NetGPO -PolicyStore $PolicyStoreName
    New-NetFirewallRule -DisplayName $FWRule -Profile Any -Direction Inbound -GPOSession $GPOSessionName -PolicyStore $GPOName -Protocol TCP -LocalPort 5985 | Out-Null
    Save-NetGPO -GPOSession $GPOSessionName | Out-Null

    Write-Verbose "A GPO for PowerShell Remoting was created for authenticated users on the domain."

    Write-Verbose "Configuring GPO policies to enable PowerShell remoting on hosts..."

    $GPOName = "Enable PSRemoting Desktops"
    $TargetOU = $DN
    $PolicyStoreName = "$Forest\" + $GPOName
    New-GPO -Name $GPOName | New-Gplink -Target $TargetOU | Out-Null

    $Domain = (Get-ADDomain).Forest
    $ID = (Get-GPO -name $GPOName).ID
    $RemotingParams = @{
        Name=$GPOName;
        Key = 'HKLM\Software\Policies\Microsoft\Windows\WinRM\Service';
    }
    
    try {
        Set-GPRegistryValue @RemotingParams -ValueName 'AllowAutoConfig' -Value 1 -Type DWord | Out-Null
        Set-GPRegistryValue @RemotingParams -ValueName 'IPv4Filter' -Value '*' -Type String | Out-Null
        Set-GPRegistryValue @RemotingParams -ValueName 'IPv6Filter' -Value '*' -Type String | Out-Null
        Write-Verbose "Registry setting for Powershell Remoting OK!"
        }
    catch { "Error enabling remoting policy" }

    $ServiceParams = @{
        Name = $GPOName;
        Key = 'HKLM\SYSTEM\CurrentControlSet\Services\WinRM';
    }
    
    try {
        Set-GPRegistryValue @ServiceParams -ValueName 'Start' -Value 2 -Type DWord | Out-Null
        Set-GPRegistryValue @ServiceParams -ValueName 'DelayedAutoStart' -Value 0 -Type DWord | Out-Null
        Write-Verbose "Service setting for Powershell Remoting OK!"
    }
    catch { "Error enabling remoting policy" }
}
