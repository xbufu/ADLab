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

        .EXAMPLE
            PS > Set-Proxy -Server "172.16.3.1:3128" -Verbose

            Configure and enable Squid proxy and display verbose output.

        .EXAMPLE
            PS > Set-Proxy -Server "172.16.3.1:3128" -GPOName "Enable Squid Proxy" -Verbose

            Configure proxy with custom GPO name.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true, HelpMessage="The address of the proxy server.")]
        [String]$Server,
        
        [Parameter(Mandatory=$false, HelpMessage="The name of the new GPO.")]
        [String]$GPOName = "Enable Proxy"
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
    $Forest = $Domain.Forest
    $DN = $Domain.DistinguishedName

    Write-Verbose "Creating GPO..."

    New-GPO -Name $GPOName | Out-Null

    $Params = @{
        Name = $GPOName;
        Key = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings';
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
