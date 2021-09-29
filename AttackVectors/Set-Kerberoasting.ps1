function Set-Kerberoasting {
    param(
        [Parameter(Mandatory=$false, HelpMessage="The number of ASREP-Roastable users.")]
        [Int]$VulnerableUsersCount = [Int]((Get-ADUser -Filter {(SamAccountName -ne "Administrator") -and (SamAccountName -ne "krbtgt") -and (SamAccountName -ne "guest")} | Measure-Object).Count * (5/100))
    )

    Write-Verbose "Getting Kerberoastable users..."

    $VulnerableUsers = (Get-ADUser -Filter {(SamAccountName -ne "Administrator") -and (SamAccountName -ne "krbtgt") -and (SamAccountName -ne "guest")}).SamAccountName | Sort-Object { Get-Random } | Select -First $VulnerableUsersCount

    foreach($Username in $VulnerableUsers) {
        Write-Verbose "Adding SPN for user: $Username"

        $ServicePath = "{0}/{1}.{2}:60111" -f ($(hostname), $Username, (Get-ADDomain).Forest)
        $DomainUserName = "{0}\{1}" -f ((Get-ADDomain).Name, $Username)
        setspn -S $ServicePath $DomainUserName
    }
}
