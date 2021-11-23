function Install-DHCP {

    <#
        .SYNOPSIS
            Installs and configures a new DHCP server in the current forest.

        .DESCRIPTION
            The function begins by installing the DHCP feature on the current machine. It then adds the necesarry security groups and authorizes the new DHCP server with the domain controller. Finally, it configures the new DHCP scope with the supplied values.

        .PARAMETER ScopeName
            The name for the new scope.

        .PARAMETER ScopeID
            The ID of the new scope, e.g. 192.168.47.0.

        .PARAMETER StartIP
            The starting IP for the new range.

        .PARAMETER EndIP
            The ending IP for the new range.

        .PARAMETER SubnetMask
            The subnet mask for the new range.

        .PARAMETER DNSServers
            The DNS servers for the new scope.

        .PARAMETER Router
            The router for the new scope.

        .PARAMETER DCFQDN
            The FQDN of the DC to register the new DHCP server with.

        .EXAMPLE
            PS > Install-DHCP -Verbose -ScopeName Default -ScopeID 192.168.47.0 -StartIP 192.168.47.100 -EndIP 192.168.47.200 -SubnetMask 255.255.255.0 -DNSServer 192.168.47.10 -Router 192.168.47.10

            Install and configure DHCP on the local DC.

        .EXAMPLE
            PS > Install-DHCP -Verbose -ScopeName Default -ScopeID 192.168.47.0 -StartIP 192.168.47.100 -EndIP 192.168.47.200 -SubnetMask 255.255.255.0 -DNSServer 192.168.47.10 -Router 192.168.47.10 -DCFQDN DC01.bufu-sec.local

            Install and configure DHCP on the specified DC.
    #>

    param(
        [Parameter(Mandatory=$true, HelpMessage="The name of the new scope.")]
        [String]$ScopeName,

        [Parameter(Mandatory=$true, HelpMessage="The ID of the new scope, e.g. 192.168.47.0.")]
        [IPAddress]$ScopeID,

        [Parameter(Mandatory=$true, HelpMessage="The starting IP for the new range.")]
        [IPAddress]$StartIP,

        [Parameter(Mandatory=$true, HelpMessage="The ending IP for the new range.")]
        [IPAddress]$EndIP,

        [Parameter(Mandatory=$true, HelpMessage="The subnet mask for the new range.")]
        [IPAddress]$SubnetMask,

        [Parameter(Mandatory=$true, HelpMessage="The DNS servers for the new scope.")]
        [IPAddress]$DNSServers,

        [Parameter(Mandatory=$true, HelpMessage="The router for the new scope.")]
        [IPAddress]$Router,

        [Parameter(Mandatory=$false, HelpMessage="The FQDN of the DC to register the new DHCP server with.")]
        [String]$DCFQDN = ([System.Net.Dns]::GetHostByName(($env:computerName))).Hostname
    )

    Write-Verbose "Installing DHCP feature..."

    Install-WindowsFeature DHCP -IncludeManagementTools

    Write-Verbose "Adding security groups..."

    Add-DhcpServerSecurityGroup
    Set-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\ServerManager\Roles\12 -Name ConfigurationState -Value 2
    Restart-Service dhcpserver

    Write-Verbose "Authorizing DHCP in Active Directory..."

    Add-DhcpServerInDC -DnsName $DCFQDN

    Write-Verbose "Configuring DHCP..."

    $Domain = (Get-ADDomain).Forest

    Add-DhcpServerv4Scope -Name $ScopeName -StartRange $StartIP -EndRange $EndIP -SubnetMask $SubnetMask -State InActive

    Set-DhcpServerv4OptionValue -ScopeID $ScopeID -DnsDomain $Domain -DnsServer $DNSServers -Router $Router
    Set-DhcpServerv4Scope -ScopeID $ScopeID -State Active
}
