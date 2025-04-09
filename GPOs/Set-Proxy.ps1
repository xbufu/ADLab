Function Set-Proxy {
    
    <#
        .SYNOPSIS
            Configures the proxy settings.

        .DESCRIPTION
            The function configures and enables the specified proxy.

        .PARAMETER Server
            The address of the proxy server.

        .PARAMETER GPOName
            The name of the new GPO.

        .PARAMETER TargetOU
            The DistinguishedName (DN) of the OU where the GPO should be linked.
            If not specified, the function defaults to the domain root.

        .EXAMPLE
            PS > Set-Proxy -Server "172.16.3.1:3128" -Verbose

            Configure and enable Squid proxy and display verbose output.

        .EXAMPLE
            PS > Set-Proxy -Server "172.16.3.1:3128" -GPOName "Enable Squid Proxy" -TargetOU "OU=Workstations,DC=example,DC=com" -Verbose

            Configure proxy with custom GPO name and target OU.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true, HelpMessage="The address of the proxy server.")]
        [String]$Server,
        
        [Parameter(Mandatory=$false, HelpMessage="The name of the new GPO.")]
        [String]$GPOName = "Enable Proxy",

        [Parameter(Mandatory=$false, HelpMessage="DN of the OU where the GPO is linked. Defaults to the base domain if not specified.")]
        [String]$TargetOU
    )

    Write-Verbose "Testing connection to proxy server..."

    $IP, $Port = $Server.split(":")
    if( (Test-NetConnection -ComputerName $IP -Port $Port).TcpTestSucceeded ) {
        Write-Verbose "Connection successful!"
    } else {
        Write-Error "Could not connect to server!"
        Exit
    }

    Import-Module GroupPolicy -Verbose:$false

    $Domain = Get-ADDomain
    $DN = $Domain.DistinguishedName

    if (-not $TargetOU) {
        $TargetOU = $DN
        Write-Verbose "No TargetOU provided. Defaulting to base domain OU: $TargetOU"
    }

    Write-Verbose "Creating GPO..."
    New-GPO -Name $GPOName | Out-Null

    $Params = @{
        Name = $GPOName;
        Key  = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings';
    }

    try {
        Set-GPRegistryValue @Params -ValueName "ProxyServer" -Value $Server -Type String | Out-Null
        Set-GPRegistryValue @Params -ValueName "ProxyEnable" -Value 1 -Type DWord | Out-Null
    } catch {
        Write-Error "Error while configuring proxy policy!"
    }

    Write-Verbose "Configuring Security Filter..."
    Set-GPPermissions -Name $GPOName -PermissionLevel GpoApply -TargetName "Domain Computers" -TargetType Group | Out-Null
    Set-GPPermissions -Name $GPOName -PermissionLevel GpoApply -TargetName "Domain Users" -TargetType User | Out-Null

    Write-Verbose "Linking and enabling new GPO..."
    New-GPLink -Name $GPOName -Target $TargetOU -LinkEnabled Yes -Enforced Yes | Out-Null
}
