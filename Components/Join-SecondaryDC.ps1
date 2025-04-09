<#
    .SYNOPSIS
        Promotes a domain-joined server to a secondary domain controller.

    .DESCRIPTION
        Installs AD DS and DNS roles and promotes the server to a DC in an existing forest.
        Accepts plain text DSRM password, which is securely converted internally.

    .PARAMETER DomainName
        FQDN of the existing domain (e.g., corp.local).

    .PARAMETER DSRMPassword
        Optional plain text DSRM password. Defaults to "Password!" if not provided.

    .EXAMPLE
        .\Join-SecondaryDC.ps1 -DomainName corp.local

    .EXAMPLE
        .\Join-SecondaryDC.ps1 -DomainName corp.local -DSRMPassword "SuperSecure123!"
#>

param (
    [Parameter(Mandatory = $true)]
    [string]$DomainName,

    [Parameter(Mandatory = $false)]
    [string]$DSRMPassword = "Password!"
)

Import-Module ServerManager
Import-Module ADDSDeployment

Write-Host "`n--- Starting Secondary Domain Controller Promotion ---`n" -ForegroundColor Cyan

Write-Host "Installing AD DS role..." -ForegroundColor Yellow
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

# Convert plain text password to SecureString
$SecureDSRMPassword = ConvertTo-SecureString $DSRMPassword -AsPlainText -Force

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
    -SafeModeAdministratorPassword $SecureDSRMPassword `
    -Force:$true `
    -Verbose
