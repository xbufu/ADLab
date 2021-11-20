Function Set-PowerSettings {
    
    <#
        .SYNOPSIS
            Configures the power plan settings.

        .DESCRIPTION
            The function enables the High Performance power plan.

        .PARAMETER GPOName

            The name of the new GPO.

        .EXAMPLE
            PS > Set-PowerSettings  -Verbose

            Configure power settings and display verbose output.

        .EXAMPLE
            PS > Set-PowerSettings -GPOName "Power Settings" -Verbose

            Configure power settings with custom GPO name.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false, HelpMessage="The name of the new GPO.")]
        [String]$GPOName = "Configure Power Settings"
    )

    Import-Module GroupPolicy -Verbose:$false

    $Domain = Get-ADDomain
    $Forest = $Domain.Forest
    $DN = $Domain.DistinguishedName

    Write-Verbose "Creating GPO..."

    New-GPO -Name $GPOName | Out-Null

    Write-Verbose "Enabling High Performance Power Plan..."

    $Params = @{
        Name = $GPOName;
        Key = 'HKLM\Software\Policies\Microsoft\Power\PowerSettings';
    }

    try {
        Set-GPRegistryValue @Params -ValueName "ActivePowerScheme" -Value "8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c" -Type String | Out-Null
    } catch {
        Write-Error "Error while configuring Power Plan policy!"
    }

    Write-Verbose "Disabling System Sleep Timeout..."

    $Params = @{
        Name = $GPOName;
        Key = 'HKLM\Software\Policies\Microsoft\Power\PowerSettings\29F6C1DB-86DA-48C5-9FDB-F2B67B1F44DA';
    }

    try {
        Set-GPRegistryValue @Params -ValueName "ACSettingIndex" -Value 0 -Type DWORD | Out-Null
    } catch {
        Write-Error "Error while configuring System Sleep Timeout policy!"
    }

    Write-Verbose "Disabling Unattended Sleep Timeout..."

    $Params = @{
        Name = $GPOName;
        Key = 'HKLM\Software\Policies\Microsoft\Power\PowerSettings\7bc4a2f9-d8fc-4469-b07b-33eb785aaca0';
    }

    try {
        Set-GPRegistryValue @Params -ValueName "ACSettingIndex" -Value 0 -Type DWORD | Out-Null
    } catch {
        Write-Error "Error while configuring System Sleep Timeout policy!"
    }

    Write-Verbose "Disabling Display Timeout..."

    $Params = @{
        Name = $GPOName;
        Key = 'HKLM\Software\Policies\Microsoft\Power\PowerSettings\3C0BC021-C8A8-4E07-A973-6B14CBCB2B7E';
    }

    try {
        Set-GPRegistryValue @Params -ValueName "ACSettingIndex" -Value 0 -Type DWORD | Out-Null
    } catch {
        Write-Error "Error while configuring System Sleep Timeout policy!"
    }

    Write-Verbose "Configuring Security Filter..."

    Set-GPPermissions -Name $GPOName -PermissionLevel GpoApply -TargetName "Domain Computers" -TargetType Group | Out-Null
    Set-GPPermissions -Name $GPOName -PermissionLevel GpoApply -TargetName "Domain Users" -TargetType User | Out-Null

    Write-Verbose "Linking and enabling new GPO..."

    New-GPLink -Name $GPOName -Target $TargetOU -LinkEnabled Yes -Enforced Yes | Out-Null
}
