Function Set-WindowsDefender {
    
    <#
        .SYNOPSIS
            Disable Windows Defender.

        .DESCRIPTION
            The function disables Windows Defender, Real-Time Protection, Routine Remediation and Automatic File Submission. Also disables SmartScreen on Microsoft Edge.

        .PARAMETER GPOName

            The name of the new GPO.

        .EXAMPLE
            PS > Set-WindowsDefender  -Verbose

            Configure Windows Defender and display verbose output.

        .EXAMPLE
            PS > Set-WindowsDefender -GPOName "Power Settings" -Verbose

            Configure Windows Defender settings with custom GPO name.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false, HelpMessage="The name of the new GPO.")]
        [String]$GPOName = "Disable Windows Defender"
    )

    Import-Module GroupPolicy -Verbose:$false

    $Domain = Get-ADDomain
    $Forest = $Domain.Forest
    $DN = $Domain.DistinguishedName

    Write-Verbose "Creating GPO..."

    New-GPO -Name $GPOName | Out-Null

    Write-Verbose "Disabling Windows Defender..."

    $Params = @{
        Name = $GPOName;
        Key = 'HKLM\Software\Policies\Microsoft\Windows Defender';
    }

    try {
        Set-GPRegistryValue @Params -ValueName "DisableAntiSpyware" -Value 1 -Type DWORD | Out-Null
    } catch {
        Write-Error "Error while configuring Windows Defender policy!"
    }

    Write-Verbose "Disabling Real-Time Protection..."

    $Params = @{
        Name = $GPOName;
        Key = 'HKLM\Software\Policies\Microsoft\Windows Defender\Real-Time Protection';
    }

    try {
        Set-GPRegistryValue @Params -ValueName "DisableRealtimeMonitoring" -Value 1 -Type DWORD | Out-Null
    } catch {
        Write-Error "Error while configuring Real-Time Proection policy!"
    }

    Write-Verbose "Disabling Routine Remediation..."

    $Params = @{
        Name = $GPOName;
        Key = 'HKLM\Software\Policies\Microsoft\Windows Defender';
    }

    try {
        Set-GPRegistryValue @Params -ValueName "DisableRoutinelyTakingAction" -Value 1 -Type DWORD | Out-Null
    } catch {
        Write-Error "Error while configuring Routine Remediation policy!"
    }

    Write-Verbose "Disabling Automatic Sample Submission..."

    $Params = @{
        Name = $GPOName;
        Key = 'HKLM\Software\Policies\Microsoft\Windows Defender\Spynet';
    }

    try {
        Set-GPRegistryValue @Params -ValueName "SpynetReporting" -Value 0 -Type DWORD | Out-Null
        Set-GPRegistryValue @Params -ValueName "SubmitSamplesConsent" -Value 2 -Type DWORD | Out-Null
    } catch {
        Write-Error "Error while configuring Automatic Sample Submission policy!"
    }

    Write-Verbose "Disabling SmartScreen on Edge..."

    $Params = @{
        Name = $GPOName;
        Key = 'HKLM\Software\Policies\Microsoft\Edge';
    }

    try {
        Set-GPRegistryValue @Params -ValueName "SmartScreenEnabled" -Value 0 -Type DWORD | Out-Null
        Set-GPRegistryValue @Params -ValueName "SmartScreenPuaEnabled" -Value 0 -Type DWORD | Out-Null
    } catch {
        Write-Error "Error while configuring Automatic Sample Submission policy!"
    }

    Write-Verbose "Configuring Security Filter..."

    Set-GPPermissions -Name $GPOName -PermissionLevel GpoApply -TargetName "Domain Computers" -TargetType Group | Out-Null
    Set-GPPermissions -Name $GPOName -PermissionLevel GpoApply -TargetName "Domain Users" -TargetType User | Out-Null

    Write-Verbose "Linking and enabling new GPO..."

    New-GPLink -Name $GPOName -Target $TargetOU -LinkEnabled Yes -Enforced Yes | Out-Null
}
