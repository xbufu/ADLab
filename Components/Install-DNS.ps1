function Install-DNS {

    <#
        .SYNOPSIS
            Installs and configures the current machine as a DNS server.

        .DESCRIPTION
            The function begins by installing the DNS feature. It then adds the primary zone and configures the server forwarder.

        .PARAMETER NetworkID
            The network ID for the primary zone, e.g. 192.168.1.0/24.

        .PARAMETER ZoneFile
            The zonefile for the primary zone, e.g. 192.168.1.2.in-addr.arpa.dns.

        .PARAMETER ServerForwarder
            The Server Forwarder for the new DNS server.

        .EXAMPLE
            PS > Install-DNS -Verbose -NetworkID 192.168.47.0/24 -ZoneFile "192.168.47.2.in-addr.arpa.dns" -ServerForwarder 1.1.1.1

            Install and configure DNS on the current host and display verbose output.
    #>

    param(
        [Parameter(Mandatory=$true, HelpMessage="The network ID for the primary zone, e.g. 192.168.1.0/24.")]
        [String]$NetworkID,

        [Parameter(Mandatory=$true, HelpMessage="The zonefile for the primary zone, e.g. 192.168.1.2.in-addr.arpa.dns.")]
        [String]$ZoneFile,

        [Parameter(Mandatory=$true, HelpMessage="The Server Forwarder for the new DNS server.")]
        [IPAddress]$ServerForwarder
    )

    Write-Verbose "Installing DNS feature..."

    Install-WindowsFeature DNS -IncludeManagementTools

    Write-Verbose "Configuring primary zone..."

    Add-DnsServerPrimaryZone -NetworkID $NetworkID -ZoneFile $ZoneFile

    Write-Verbose "Adding Server Forwarder..."

    Add-DnsServerForwarder -IPAddress $ServerForwarder -PassThru
}
