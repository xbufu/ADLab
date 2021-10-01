function Invoke-ForestDeploy {

    <#
        .SYNOPSIS
            Install a new Active Directory forest.

        .DESCRIPTION
            The function installs the AD DS feature and sets up a new Active Directory forest, without requiring any user input. Restarts the computer upon completion.

        .PARAMETER Domain
            The domain name for the new forest.

        .PARAMETER DSRMPassword
            The DSRM password for the new forest.

        .EXAMPLE
            PS > Invoke-ForestDeploy -Domain bufu-sec.local

            Installs a new forest with FQDN of "bufu-sec.local" with default DSRM password of "Password!".

        .EXAMPLE
            PS > Invoke-ForestDeploy -Domain "bufu-sec.local" -DSRMPassword "P@ssword!" -Verbose

            Installs a new forest with FQDN of "bufu-sec.local" with the DSRM password set to "P@ssword!" and displaying debug messages.
    #>
    
    param (
        [Parameter(Mandatory=$true, HelpMessage="Domain name for the root domain, e.g. lab.local .")]
        [String]$Domain,

        [Parameter(Mandatory=$false, HelpMessage="DSRM password for the new domain.")]
        [String]$DSRMPassword = "Password!"
    )

    Write-Verbose "Installing AD DS feature..."

    Install-WindowsFeature -Name "AD-Domain-Services" -IncludeManagementTools

    Write-Verbose "Installing new forest: $Domain"
    
    $Password = ConvertTo-SecureString -AsPlainText -String $DSRMPassword -Force
    $NetbiosName = $Domain.split(".")[0].ToUpper()

    Install-ADDSForest -DomainName "$Domain" -DomainNetbiosName "$NetbiosName" -SafeModeAdministratorPassword $Password -CreateDnsDelegation:$false -DatabasePath "C:\Windows\NTDS" -SysvolPath "C:\Windows\SYSVOL" -LogPath "C:\Windows\NTDS" -DomainMode "WinThreshold" -ForestMode "WinThreshold" -NoRebootOnCompletion:$false -InstallDNS:$false -Force:$true
}
