function Set-AsrepRoasting {

    param(
        [Parameter(Mandatory=$false, HelpMessage="The number of ASREP-Roastable users.")]
        [Int]$VulnerableUsersCount = [Int]((Get-ADUser -Filter {(SamAccountName -ne "Administrator") -and (SamAccountName -ne "krbtgt") -and (SamAccountName -ne "guest")} | Measure-Object).Count * (5/100))
    )

    Write-Verbose "Getting ASREP-Roastable users..."
    
    $VulnerableUsers = (Get-ADUser -Filter {(SamAccountName -ne "Administrator") -and (SamAccountName -ne "krbtgt") -and (SamAccountName -ne "guest")}).SamAccountName | Sort-Object { Get-Random } | Select -First $VulnerableUsersCount

    foreach($User in $VulnerableUsers) {
        Write-Verbose "Setting DoesNotRequirePreAuth flag for user: $User"
        Set-ADAccountControl -Identity $User -DoesNotRequirePreAuth 1    
    }
}
