<#
    .SYNOPSIS
        Joins the computer to an Active Directory domain.

    .DESCRIPTION
        Prompts for credentials and joins the current machine to the specified domain.
        Optionally supports setting the OU path and auto-restarts after joining.

    .PARAMETER DomainName
        The FQDN of the domain to join (e.g., corp.local)

    .PARAMETER OUPath
        Optional Distinguished Name of the OU to place the computer in 
        (e.g., "OU=Servers,DC=corp,DC=local")

    .EXAMPLE
        .\Add-Computer.ps1 -DomainName corp.local

    .EXAMPLE
        .\Add-Computer.ps1 -DomainName corp.local -OUPath "OU=DCs,DC=corp,DC=local"
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$DomainName,

    [Parameter(Mandatory = $false)]
    [string]$OUPath
)

$cred = Get-Credential -Message "Enter credentials to join domain $DomainName"

if ($OUPath) {
    Write-Host "Joining domain $DomainName in OU: $OUPath..." -ForegroundColor Cyan
    Add-Computer -DomainName $DomainName -Credential $cred -OUPath $OUPath -Restart -Force
} else {
    Write-Host "Joining domain $DomainName..." -ForegroundColor Cyan
    Add-Computer -DomainName $DomainName -Credential $cred -Restart -Force
}
