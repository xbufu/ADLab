function Invoke-DCPrep {

    <#
        .SYNOPSIS
            Prepares the current computer to be used as a new Domain Controller.

        .DESCRIPTION
            The function sets a static IP address, configures the localhost as the primary DNS server and renames the computer. Restarts after use.

        .PARAMETER Hostname
            The new hostname for the domain controller.

        .PARAMETER NewIPv4DNSServer
            The IP address of the new DNS server for Internet access. Defaults to 1.1.1.1 (Cloudflare).

        .PARAMETER NewIPv4Address
            The new static IPv4 address. Defaults to current network ID with .10 suffix. If set, requires NewIPv4Gateway parameter to be set as well.

        .PARAMETER NewIPv4Gateway
            The new IPv4 default gateway. Defaults to current network ID with .2 suffix. If set, requires NewIPv4Address parameter to be set as well.

        .EXAMPLE
            PS > Invoke-DCPrep -Verbose

            Prepare the current VM with all default values while displaying verbose output.

        .EXAMPLE
            PS > Invoke-DCPrep -Hostname "DC" -NewIPv4DNSServer "8.8.8.8"

            Set custom hostname and use Google DNS for Internet access.

        .EXAMPLE
            PS > Invoke-DCPrep -Verbose -NewIPv4Address "192.168.1.99" -NewIPv4Gateway "192.168.1.1"

            Use custom IP and default gateway and display verbose output.
    #>

    [CmdletBinding(DefaultParametersetName='None')] 
    param(
        [Parameter(Mandatory=$false, HelpMessage="The new hostname for the domain controller.")]
        [String]$Hostname = "DC01",

        [Parameter(Mandatory=$false, HelpMessage="The IP address of the new DNS server for Internet access.")]
        [String]$NewIPv4DNSServer = "1.1.1.1",

        [Parameter(ParameterSetName="IPv4", Mandatory=$true, HelpMessage="The new static IPv4 address.")]
        [String]$NewIPv4Address,

        [Parameter(ParameterSetName="IPv4", Mandatory=$true, HelpMessage="The new IPv4 default gateway.")]
        [String]$NewIPv4Gateway
    )

    $InterfaceIndex = (Get-NetAdapter).ifIndex

    if ((! $NewIPv4Address) -and (! $NewIPv4Gateway)) {
        $CurrentIPv4Address = (Get-NetIpAddress -InterfaceIndex $InterfaceIndex -AddressFamily "IPv4").IPAddress

        $Octets = $CurrentIPv4Address.split(".")
        $Subnet = "$($Octets[0]).$($Octets[1]).$($Octets[2])"

        $NewIPv4Address = "$Subnet.10"
        $NewIPv4Gateway = "$Subnet.2"
    }

    Write-Verbose "Removing previous IP addresses..."

    Remove-NetIPAddress -AddressFamily "IPv4" -InterfaceIndex $InterfaceIndex -Confirm:$false
    Remove-NetIPAddress -AddressFamily "IPv6" -InterfaceIndex $InterfaceIndex -Confirm:$false

    Write-Verbose "Removing previous default gateways..."

    Remove-NetRoute -AddressFamily "IPv4" -InterfaceIndex $InterfaceIndex -Confirm:$false
    Remove-NetRoute -AddressFamily "IPv6" -InterfaceIndex $InterfaceIndex -Confirm:$false

    Write-Verbose "Setting new static IPv4 address..."

    New-NetIpAddress -InterfaceIndex $InterfaceIndex -AddressFamily "IPv4" -IPAddress "$NewIPv4Address" -PrefixLength 24 -DefaultGateway "$NewIPv4Gateway" | Out-Null

    Write-Verbose "Setting new DNS servers..."

    Set-DnsClientServerAddress -InterfaceIndex $InterfaceIndex -ServerAddresses ("127.0.0.1", "$NewIPv4DNSServer")

    Write-Verbose "Renaming computer..."

    Rename-Computer -NewName "$Hostname" -Restart -Force
}

Invoke-DCPrep -Verbose -Hostname "DC"
