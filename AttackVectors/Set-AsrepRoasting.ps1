function Set-ASREPRoasting {

    <#
        .SYNOPSIS
            Adds ASREP-roastable users to the domain.

        .DESCRIPTION
            The function gets a certain amount of random user from the domain and sets the DoesNotRequirePreAuth flag for each. Excludes default accounts like Administrator and krbtgt. Makes 5% of users ASREP-roastable by default.

        .PARAMETER VulnerableUsersCount
            The number of ASREP-roastable users.

        .PARAMETER Users
            The user to make ASREP-roastable.

        .EXAMPLE
            PS > Set-ASREPRoasting -Verbose

            Make 5% of users ASREP-roastable and display verbose output.

        .EXAMPLE
            PS > Set-ASREPRoasting -VulnerableUsersCount 10

            Make 10 random users in the domain ASREP-roastable.

        .EXAMPLE
            PS > Set-ASREPRoasting -Users bufu -Verbose

            Make user bufu ASREP-roastable and display verbose output.

        .EXAMPLE
            PS > Set-ASREPRoasting -Users ("bufu", "pepe") -Verbose

            Make supplied list of users ASREP-roastable and display verbose output.
    #>

    param(
        [Parameter(Mandatory=$false, HelpMessage="The number of ASREP-roastable users.")]
        [Int]$VulnerableUsersCount = [Int]((Get-ADUser -Filter {(SamAccountName -ne "Administrator") -and (SamAccountName -ne "krbtgt") -and (SamAccountName -ne "guest")} | Measure-Object).Count * (5/100)),

        [Parameter(Mandatory=$false, HelpMessage="The user to make ASREP-roastable.")]
        [String]$Users
    )


    if($Users) {
        $VulnerableUsers = $User
    } {
        Write-Verbose "Getting ASREP-roastable users..."

        $VulnerableUsers = (Get-ADUser -Filter {(SamAccountName -ne "Administrator") -and (SamAccountName -ne "krbtgt") -and (SamAccountName -ne "guest")}).SamAccountName | Sort-Object { Get-Random } | Select -First $VulnerableUsersCount
    }    

    foreach($Username in $VulnerableUsers) {
        Write-Verbose "Setting DoesNotRequirePreAuth flag for user: $Username"
        Set-ADAccountControl -Identity $Username -DoesNotRequirePreAuth 1    
    }
}
