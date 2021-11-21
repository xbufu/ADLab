Function Set-ScriptExecution {

    <#
        .SYNOPSIS
            Enables script execution.

        .DESCRIPTION
            The function creates and configures a new GPO to set the PowerShell Script Execution Policy to Unrestricted.

        .PARAMETER GPOName

            The name of the new GPO.

        .EXAMPLE
            PS > Set-ScriptExecution -Verbose

            Enable Script Execution and display verbose output. Use default GPO name "Enable Script Execution"

        .EXAMPLE
            PS > Set-ScriptExecution -GPOName "Enable Scripts" -Verbose

            Enable Script Execution with custom GPO name.
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false, HelpMessage="The name of the new GPO.")]
        [String]$GPOName = "Enable Script Execution"
    )

    Import-Module GroupPolicy -Verbose:$false

    $Domain = Get-ADDomain
    $Forest = $Domain.Forest
    $DN = $Domain.DistinguishedName
    $TargetOU = $DN

    Write-Verbose "Creating GPO..."

    New-GPO -Name $GPOName | Out-Null

    Write-Verbose "Configuring PowerShell Execution Policy..."

    $Params = @{
        Name = $GPOName;
        Key = 'HKLM\Software\Policies\Microsoft\Windows\PowerShell';
    }

    try {
        Set-GPRegistryValue @Params -ValueName 'EnableScripts' -Value 1 -Type DWord | Out-Null
        Set-GPRegistryValue @Params -ValueName 'ExecutionPolicy' -Value "Unrestricted" -Type String | Out-Null
    } catch {
        Write-Error "Error while configuring Execution Policy!"
    }

    Write-Verbose "Configuring Security Filter..."

    Set-GPPermissions -Name $GPOName -PermissionLevel GpoApply -TargetName "Domain Computers" -TargetType Group | Out-Null
    Set-GPPermissions -Name $GPOName -PermissionLevel GpoApply -TargetName "Domain Users" -TargetType User | Out-Null

    Write-Verbose "Linking and enabling new GPO..."

    New-GPLink -Name $GPOName -Target $TargetOU -LinkEnabled Yes -Enforced Yes | Out-Null
}
