<#
    .SYNOPSIS
        Promotes a domain-joined server to a secondary domain controller.

    .DESCRIPTION
        Installs AD DS and DNS roles and promotes the server to a domain controller
        in an existing forest. Requires the machine to already be joined to the domain.

    .PARAMETER DomainName
        The FQDN of the domain (e.g., corp.local).

    .PARAMETER DSRMPassword
        Directory Services Restore Mode password. If not provided, prompts securely.

    .EXAMPLE
        .\Join-SecondaryDC.ps1 -DomainName corp.local

    .EXAMPLE
        .\Join-SecondaryDC.ps1 -DomainName corp.local -DSRMPassword (ConvertTo-SecureString "MyPass123" -AsPlainText -Force)
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$DomainName,

    [Parameter(Mandatory = $false)]
    [SecureString]$DSRMPassword
)

Import-Module ServerManager
Import-Module ADDSDeployment

Write-Host "`n--- Starting Secondary Domain Controller Promotion ---`n" -ForegroundColor Cyan

Write-Host "Installing AD DS role..." -ForegroundColor Yellow
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

if (-not $DSRMPassword) {
    $DSRMPassword = Read-Host "Enter Directory Services Restore Mode (DSRM) password" -AsSecureString
}

Write-Host "Promoting this server to a domain controller in '$DomainName'..." -ForegroundColor Yellow

$cred = Get-Credential -Message "Enter Domain Admin credentials for '$DomainName'"

Install-ADDSDomainController `
    -DomainName $DomainName `
    -InstallDns `
    -Credential $cred `
    -SiteName "Default-First-Site-Name" `
    -NoGlobalCatalog:$false `
    -DatabasePath "C:\Windows\NTDS" `
    -LogPath "C:\Windows\NTDS" `
    -SYSVOLPath "C:\Windows\SYSVOL" `
    -SafeModeAdministratorPassword $DSRMPassword `
    -Force:$true `
    -Verbose
