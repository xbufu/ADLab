Function Set-UnconstrainedDelegation {
    
    <#
        .SYNOPSIS
            Enable Unconstrained Delegation for the specified computer and simulate login event by a Domain Admin.

        .DESCRIPTION
            The function enables Unconstrained Delegation for the target computer by setting the TrustedForDelegation flag. It then creates a scheduled job to simulate a login event by a Domain Admin on the target computer. This leaves a ticket in memory on the target that we can use to elevate our privileges.

        .PARAMETER Target

            The name of the target computer.

        .PARAMETER JobName

            The name of the new job.

        .PARAMETER JobInterval

            The interval at which the job should run at in minutes.

        .EXAMPLE
            PS > Set-UnconstrainedDelegation -Target "WS01" -Verbose

            Configure Unconstrained Delegation on the target computer and display verbose output.

        .EXAMPLE
            PS > Set-UnconstrainedDelegation -Target "WS01" -JobName "Login Event" -JobInterval 5 -Verbose

            Set custom job name and run job every 5 minutes.
    #>

    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true, HelpMessage="The name of the target computer.")]
        [String]$Target,

        [Parameter(Mandatory=$false, HelpMessage="The name of the new job.")]
        [String]$JobName = "Unconstrained Delegation Login Event",

        [Parameter(Mandatory=$false, HelpMessage="The interval at which the job should run at in minutes.")]
        [Int]$JobInterval = 1
    )

    Write-Verbose "Setting the TrustedForDelegation Flag on the Target..."

    Get-ADComputer -Identity $Target | Set-ADAccountControl -TrustedForDelegation $true

    Write-Verbose "Setting up Scheduled Job..."

    $JobTrigger = New-JobTrigger -Once -At (Get-Date).Date -RepeatIndefinitely -RepetitionInterval (New-TimeSpan -Minutes $JobInterval)
    $JobOptions = New-ScheduledJobOption -RunElevated -ContinueIfGoingOnBattery -StartIfOnBattery
    $JobCommand = "Get-ChildItem \\$Target\c$"

    Register-ScheduledJob -Name $JobName -ScriptBlock ([ScriptBlock]::Create($JobCommand)) -Trigger $JobTrigger -ScheduledJobOption $JobOptions | Out-Null
}
