Function Set-DebloatTaskbar {

    <#
        .SYNOPSIS
            Debloats the taskbar.

        .DESCRIPTION
            The function removes taskbar bloat like Cortana search, people, and News and Interests.

        .PARAMETER GPOName

            The name of the new GPO.

        .EXAMPLE
            PS > Set-DebloatTaskbar -Verbose

            Debloat the taskbar and display verbose output. Use default GPO name "Debloat Taskbar"

        .EXAMPLE
            PS > Set-DebloatTaskbar -GPOName "Taskbar" -Verbose

            Debloat taskbar with custom GPO name.
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false, HelpMessage="The name of the new GPO.")]
        [String]$GPOName = "Debloat Taskbar"
    )

    Import-Module GroupPolicy -Verbose:$false

    $Domain = Get-ADDomain
    $Forest = $Domain.Forest
    $DN = $Domain.DistinguishedName
    $TargetOU = $DN

    Write-Verbose "Creating GPO..."

    New-GPO -Name $GPOName | Out-Null

    Write-Verbose "Disabling News and Interests..."

    $Params = @{
        Name = $GPOName;
        Key = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds';
    }

    try {
        Set-GPRegistryValue @Params -ValueName 'EnableFeeds' -Value 0 -Type DWord | Out-Null
    } catch { 
        Write-Error "Error while configuring News and Interests policy!"
    }

    Write-Verbose "Disabling People Bar..."

    $Params = @{
        Name = $GPOName;
        Key = 'HKCU\Software\Policies\Microsoft\Windows\Explorer';
    }

    try {
        Set-GPRegistryValue @Params -ValueName 'HidePeopleBar' -Value 1 -Type DWord | Out-Null
    } catch { 
        Write-Error "Error while configuring People Bar policy!"
    }

    Write-Verbose "Disabling Meet Now..."

    $Params = @{
        Name = $GPOName;
        Key = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer';
    }

    try {
        Set-GPRegistryValue @Params -ValueName 'HideSCAMeetNow' -Value 1 -Type DWord | Out-Null
    } catch { 
        Write-Error "Error while configuring Meet Now policy!"
    }

    Write-Verbose "Disabling Task View..."

    $Params = @{
        Name = $GPOName;
        Key = 'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced';
    }

    try {
        Set-GPRegistryValue @Params -ValueName 'ShowTaskViewButton' -Value 0 -Type DWord | Out-Null
    } catch { 
        Write-Error "Error while configuring Task View policy!"
    }

    Write-Verbose "Disabling Cortana..."

    $Params = @{
        Name = $GPOName;
        Key = 'HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search';
    }

    try {
        Set-GPRegistryValue @Params -ValueName 'AllowCortana' -Value 0 -Type DWord | Out-Null
        Set-GPRegistryValue @Params -ValueName 'AllowCloudSearch' -Value 0 -Type DWord | Out-Null
    } catch { 
        Write-Error "Error while configuring Cortana policy!"
    }

    Write-Verbose "Disabling Search Bar..."

    $Params = @{
        Name = $GPOName;
        Key = 'HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search';
    }

    try {
        Set-GPRegistryValue @Params -ValueName 'SearchboxTaskbarMode ' -Value 0 -Type DWord | Out-Null
    } catch { 
        Write-Error "Error while configuring Search Bar policy!"
    }

    Write-Verbose "Configuring Security Filter..."

    Set-GPPermissions -Name $GPOName -PermissionLevel GpoApply -TargetName "Domain Computers" -TargetType Group | Out-Null
    Set-GPPermissions -Name $GPOName -PermissionLevel GpoApply -TargetName "Domain Users" -TargetType User | Out-Null

    Write-Verbose "Linking and enabling new GPO..."

    New-GPLink -Name $GPOName -Target $TargetOU -LinkEnabled Yes -Enforced Yes | Out-Null
}
