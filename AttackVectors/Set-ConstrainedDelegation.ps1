Function Set-ConstrainedDelegation {
    
    <#
        .SYNOPSIS
            Enable Constrained Delegation for the specified user or computer.

        .DESCRIPTION
            The function enables Cconstrained Delegation for the target user or computer by setting the msDS-AllowedToDelegateTo property and fills it with the supplied SPNs. Defaults to the CIFS service on the Domain Controller.

        .PARAMETER Target

            The name of the target user or computer.

        .PARAMETER SPNs

            The SPNs the target will be allowed to delegate to.

        .EXAMPLE
            PS > Set-ConstrainedDelegation -Target "WS01" -Verbose

            Configure Constrained Delegation on the target computer for the CIFS service on the DC and display verbose output.

        .EXAMPLE
            PS > Set-ConstrainedDelegation -Target "WS01" -SPNs @("HOST/BUFU-DC.bufu-sec.local", "RPCSS/BUFU-DC.bufu-sec.local") -Verbose

            Set custom SPNs to get access to WMI on the DC.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true, HelpMessage="The name of the target user or computer.")]
        [String]$Target,

        [Parameter(Mandatory=$false, HelpMessage="The SPNs the target will be allowed to delegate to.")]
        [Array]$SPNs = @("CIFS/$((Get-ADDomainController).HostName)")
    )

    Write-Verbose "Setting the msDS-AllowedToDelegateTo on the Target..."

    Set-ADComputer -Identity $Target -Add @{'msDS-AllowedToDelegateTo'=$SPNs}
}
