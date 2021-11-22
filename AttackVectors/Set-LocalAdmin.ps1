Function Set-LocalAdmin {
    
    <#
        .SYNOPSIS
            Make a user a local administrator on the target machine.

        .DESCRIPTION
            The function connects to the remote machine and adds the user to the local administrators group.

        .PARAMETER User

            The user to add as a local administrator.

        .PARAMETER Computer

            The target computer.

        .EXAMPLE
            PS > Set-LocalAdmin -User bufu -Computer WS01 -Verbose

            Make bufu a local administrator on WS01 and display verbose output.
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true, HelpMessage="The user to add as a local administrator.")]
        [String]$UserName,

        [Parameter(Mandatory=$true, HelpMessage="The target computer.")]
        [String]$ComputerName
    )

    Import-Module ActiveDirectory -Verbose:$false

    Write-Verbose "Validating target username..."

    try {
        Get-ADUser -Identity $UserName | Out-Null
    } catch {
        Write-Error "Invalid username!"
        Exit
    }

    Write-Verbose "Validating target computer name..."

    try {
        Get-ADComputer -Identity $ComputerName | Out-Null
    } catch {
        Write-Error "Invalid computer name!"
        Exit
    }

    Write-Verbose "Adding $UserName as local administrator on $ComputerName..."

    $Command = [ScriptBlock]::Create("net localgroup Administrators /add $((Get-ADDomain).NetBIOSName)\$UserName")
    Invoke-Command -ComputerName $ComputerName -ScriptBlock $Command | Out-Null
}
