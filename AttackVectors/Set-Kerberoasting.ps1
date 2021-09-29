function Set-Kerberoasting {
    <#
        .SYNOPSIS
            Adds Kerberoastable users to the domain.

        .DESCRIPTION
            The function gets a certain amount of random user from the domain and adds a SPN for each. Excludes default accounts like Administrator and krbtgt. Makes 5% of users kerberoastable by default.

        .PARAMETER VulnerableUsersCount
            The number of Kerberoastable users.

        .PARAMETER User
            The user to make kerberoastable.

        .EXAMPLE
            PS > Set-Kerberoasting -Verbose

            Make 5% of users kerberoastable and display verbose output.

        .EXAMPLE
            PS > Set-Kerberoasting -VulnerableUsersCount 10

            Make 10 random users in the domain kerberoastable.

        .EXAMPLE
            PS > Set-Kerberoasting -User bufu -Verbose

            Make user bufu kerberoastable and display verbose output.
    #>

    param(
        [Parameter(Mandatory=$false, HelpMessage="The number of Kerberoastable users.")]
        [Int]$VulnerableUsersCount = [Int]((Get-ADUser -Filter {(SamAccountName -ne "Administrator") -and (SamAccountName -ne "krbtgt") -and (SamAccountName -ne "guest")} | Measure-Object).Count * (5/100)),

        [Parameter(Mandatory=$false, HelpMessage="The user to make kerberoastable.")]
        [String]$User
    )


    if($User) {
        $VulnerableUsers = $User
    } else {
        Write-Verbose "Getting Kerberoastable users..."
        
        $VulnerableUsers = (Get-ADUser -Filter {(SamAccountName -ne "Administrator") -and (SamAccountName -ne "krbtgt") -and (SamAccountName -ne "guest")}).SamAccountName | Sort-Object { Get-Random } | Select -First $VulnerableUsersCount
    }

    foreach($Username in $VulnerableUsers) {
        Write-Verbose "Adding SPN for user: $Username"

        $ServicePath = "{0}/{1}.{2}:60111" -f ($(hostname), $Username, (Get-ADDomain).Forest)
        $DomainUserName = "{0}\{1}" -f ((Get-ADDomain).Name, $Username)
        setspn -S $ServicePath $DomainUserName
    }
}
