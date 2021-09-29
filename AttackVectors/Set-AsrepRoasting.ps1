function Set-AsrepRoasting {

    <#
        .SYNOPSIS
            Adds ASREP-Roastable users to the domain.

        .DESCRIPTION
            The function gets a certain amount of random user from the domain and sets the DoesNotRequirePreAuth flag for each. Excludes default accounts like Administrator and krbtgt. Makes 5% of users ASREP-Roastable by default.

        .PARAMETER VulnerableUsersCount
            The number of ASREP-Roastable users.

        .PARAMETER User
            The user to make ASREP-Roastable.

        .EXAMPLE
            PS > Set-AsrepRoasting -Verbose

            Make 5% of users ASREP-Roastable and display verbose output.

        .EXAMPLE
            PS > Set-AsrepRoasting -VulnerableUsersCount 10

            Make 10 random users in the domain ASREP-Roastable.

        .EXAMPLE
            PS > Set-AsrepRoasting -User bufu -Verbose

            Make user bufu ASREP-Roastable and display verbose output.
    #>

    param(
        [Parameter(Mandatory=$false, HelpMessage="The number of ASREP-Roastable users.")]
        [Int]$VulnerableUsersCount = [Int]((Get-ADUser -Filter {(SamAccountName -ne "Administrator") -and (SamAccountName -ne "krbtgt") -and (SamAccountName -ne "guest")} | Measure-Object).Count * (5/100)),

        [Parameter(Mandatory=$false, HelpMessage="The user to make ASREP-Roastable.")]
        [String]$User
    )


    if($User) {
        $VulnerableUsers = $User
    } {
        Write-Verbose "Getting ASREP-Roastable users..."

        $VulnerableUsers = (Get-ADUser -Filter {(SamAccountName -ne "Administrator") -and (SamAccountName -ne "krbtgt") -and (SamAccountName -ne "guest")}).SamAccountName | Sort-Object { Get-Random } | Select -First $VulnerableUsersCount
    }    

    foreach($Username in $VulnerableUsers) {
        Write-Verbose "Setting DoesNotRequirePreAuth flag for user: $Username"
        Set-ADAccountControl -Identity $Username -DoesNotRequirePreAuth 1    
    }
}
