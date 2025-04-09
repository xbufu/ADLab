Function Disable-WindowsUpdate {

    <#
        .SYNOPSIS
            Disables Automatic Windows Updates via Group Policy.

        .DESCRIPTION
            Creates and links a GPO that disables automatic updates on target machines
            by setting the appropriate registry keys via Group Policy.

        .PARAMETER GPOName
            The name of the GPO to create.

        .EXAMPLE
            PS > Disable-WindowsUpdate

            Disables automatic updates with default GPO name "Disable Windows Update".

        .EXAMPLE
            PS > Disable-WindowsUpdate -GPOName "No Auto Updates"

            Disables automatic updates with custom GPO name.
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false, HelpMessage="Name of the GPO to create.")]
        [string]$GPOName = "Disable Windows Update"
    )

    Import-Module GroupPolicy -Verbose:$false

    $Domain = Get-ADDomain
    $Forest = $Domain.Forest
    $DN = $Domain.DistinguishedName

    Write-Verbose "Creating GPO..."
    New-GPO -Name $GPOName | Out-Null

    Write-Verbose "Setting registry values to disable automatic updates..."

    $BaseKey = "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"

    # Ensure parent path exists
    Set-GPRegistryValue -Name $GPOName -Key "HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" -ValueName "" -Type String -Value "" | Out-Null

    # Disable automatic updates completely
    Set-GPRegistryValue -Name $GPOName -Key $BaseKey -ValueName "NoAutoUpdate" -Type DWord -Value 1 | Out-Null

    Write-Verbose "Setting security filtering to Domain Computers and Users..."

    Set-GPPermissions -Name $GPOName -PermissionLevel GpoApply -TargetName "Domain Computers" -TargetType Group | Out-Null
    Set-GPPermissions -Name $GPOName -PermissionLevel GpoApply -TargetName "Domain Users" -TargetType User | Out-Null

    Write-Verbose "Linking and enabling new GPO..."

    New-GPLink -Name $GPOName -Target $DN -LinkEnabled Yes -Enforced Yes | Out-Null

    Write-Verbose "Done. GPO to disable Windows Update has been created and linked."
}
