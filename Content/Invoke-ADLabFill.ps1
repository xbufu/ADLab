$Global:Domain = (Get-WmiObject -Class Win32_ComputerSystem).Domain
$Global:DomainPrefix, $Global:DomainSuffix = $Global:Domain.split(".")
$Global:Groups = "Chads", "Normies", "Degens"
$Global:Passwords = "Password!", "P@ssword?", "SuperSecurePassw0rd!", "GigaCh@d69"

function New-Name {
    $AllNames = Import-Csv -Path "$PSScriptRoot\Names.csv" -Delimiter ","
    $AllNamesCount = $AllNames.Count

    $LastName = $AllNames[(Get-Random -Minimum 0 -Maximum $AllNamesCount)].LastName

    $RandomSex = (Get-Random @('Female', 'Male'))
    $FirstNameFieldName = "{0}FirstName" -f $RandomSex
    $FirstName = $AllNames[(Get-Random -Minimum 0 -Maximum $AllNamesCount)].$FirstNameFieldName
    
    $Name = New-Object -TypeName "psobject"
    $Name | Add-Member -MemberType NoteProperty -Name "FirstName" -Value $FirstName
    $Name | Add-Member -MemberType NoteProperty -Name "LastName" -Value $LastName

    Return $Name
}

function Test-ADUser {

    <#
        .SYNOPSIS
            Tests if the supplied username exists already in the current forest.

        .DESCRIPTION
            The function tests if the username already exists by trying to assign the object to a variable. If the variable was set, the user exists. Returns true or false.

        .PARAMETER Username
            The username to check for.

        .EXAMPLE
            PS > Test-ADUser -Username "testuser"

            Checks if the user "testuser" already exists in the current forest.
    #>

    param(
        [Parameter(Mandatory=$true, HelpMessage="The username to check for.")]
        [String]$Username
    )

    try {
        $UserExists = Get-ADUser $Username
    } catch {}

    if ($UserExists) {
        Return $true
    } else {
        Return $false
    }
}

function Invoke-ADLabFill {

    <#
        .SYNOPSIS
            Populates the current forest with defined groups, OUs and user objects.

        .DESCRIPTION
            The function begins by creating the groups and OUs defined in the global Groups variable. It then generates 10 user objects for each OU by default. Requires Names.csv to be present in the same directory.

        .PARAMETER UserCount
            The number of users to create for each OU.

        .EXAMPLE
            PS > Invoke-ADLabFill -Verbose

            Fill forest with objects and display verbose output.

        .EXAMPLE
            PS > Invoke-ADLabFill -Verbose -UserCount 50

            Create 50 users for each OU and display verbose output.
    #>

    param(
        [Parameter(Mandatory=$false, HelpMessage="The number of users to create for each OU")]
        [Int]$UserCount = 10
    )

    Write-Verbose "Adding groups..."

    foreach ($GroupName in $Global:Groups) {
        Write-Verbose "Creating group: $GroupName"
        New-ADGroup -Name "$GroupName" -GroupScope "Global"
    }

    Write-Verbose "Adding OUs..."

    foreach ($OUName in $Global:Groups) {
        Write-Verbose "Creating OU: $OUName"
        New-ADOrganizationalUnit -Name "$OUName" -Path "DC=$Global:DomainPrefix,DC=$Global:DomainSuffix"
    }

    Write-Verbose "Creating users..."

    foreach ($GroupName in $Global:Groups) {
        $Count = 0

        while ($Count -lt $UserCount) {
            $Name = New-Name
            $FirstName = $Name.FirstName
            $LastName = $Name.LastName
            $FullName = "{0} {1}" -f ($FirstName, $LastName)
            $SamAccountName = ("{0}.{1}" -f ($FirstName[0], $LastName)).ToLower()
            $UserPrincipalName = "{0}.{1}@{2}" -f ($FirstName[0], $LastName, $Global:Domain)
            $Password = ConvertTo-SecureString $Global:Passwords[(Get-Random -Minimum 0 -Maximum $Global:Passwords.Length)] -AsPlainText -Force
            $Path = "OU={0},DC={1},DC={2}" -f ($GroupName, $Global:DomainPrefix, $Global:DomainSuffix)

            if (Test-ADUser "$SamAccountName" ) {
                Continue
            } else {
                New-ADUser -Name "$FullName" -GivenName "$FirstName" -Surname "$LastName" -SamAccountName "$SamAccountName" -UserPrincipalName "$UserPrincipalName" -Path "$Path" -AccountPassword $Password -Enabled:$true
                Add-ADGroupMember -Identity $GroupName -Members $SamAccountName
                $Count++
            }
        }
    }
}
