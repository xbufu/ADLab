Function Set-ScriptExecution {

    <#
        .SYNOPSIS
            Enables script execution.

        .DESCRIPTION
            The function creates and configures a new GPO to set the PowerShell Script Execution Policy to Unrestricted.

        .PARAMETER GPOName
            The name of the new GPO.

        .PARAMETER TargetOU
            The DistinguishedName (DN) of the OU where the GPO should be linked.
            If not specified, the function defaults to the root of the domain.

        .EXAMPLE
            PS > Set-ScriptExecution -Verbose

            Enable Script Execution and display verbose output. Uses default GPO name and base domain OU.

        .EXAMPLE
            PS > Set-ScriptExecution -GPOName "Enable Scripts" -TargetOU "OU=Workstations,DC=example,DC=com" -Verbose

            Enable Script Execution with a custom GPO name and target OU.
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false, HelpMessage="The name of the new GPO.")]
        [String]$GPOName = "Enable Script Execution",

        [Parameter(Mandatory=$false, HelpMessage="DN of the OU where the GPO is linked. Defaults to the root domain if not specified.")]
        [String]$TargetOU
    )

    Import-Module GroupPolicy -Verbose:$false

    $Domain = Get-ADDomain
    $DN = $Domain.DistinguishedName

    if (-not $TargetOU) {
        $TargetOU = $DN
        Write-Verbose "No TargetOU provided. Defaulting to base domain OU: $TargetOU"
    }

    Write-Verbose "Creating GPO..."
    New-GPO -Name $GPOName | Out-Null

    Write-Verbose "Configuring PowerShell Execution Policy..."

    $Params = @{
        Name = $GPOName;
        Key  = 'HKLM\Software\Policies\Microsoft\Windows\PowerShell';
    }

    try {
        Set-GPRegistryValue @Params -ValueName 'EnableScripts' -Value 1 -Type DWord | Out-Null
        Set-GPRegistryValue @Params -ValueName 'ExecutionPolicy' -Value "Unrestricted" -Type String | Out-Null
    }
    catch {
        Write-Error "Error while configuring Execution Policy!"
    }

    Write-Verbose "Configuring Security Filter..."

    Set-GPPermissions -Name $GPOName -PermissionLevel GpoApply -TargetName "Domain Computers" -TargetType Group | Out-Null
    Set-GPPermissions -Name $GPOName -PermissionLevel GpoApply -TargetName "Domain Users" -TargetType User | Out-Null

    Write-Verbose "Linking and enabling new GPO..."
    New-GPLink -Name $GPOName -Target $TargetOU -LinkEnabled Yes -Enforced Yes | Out-Null
}
