function Add-ACL {

    param(
            [Parameter(Mandatory=$true)]
            [ValidateNotNullOrEmpty()]
            [System.Security.Principal.IdentityReference]$SourceObject,

            [Parameter(Mandatory=$true)]
            [ValidateNotNullOrEmpty()]
            [string]$TargetObject,

            [Parameter(Mandatory=$true)]
            [ValidateNotNullOrEmpty()]
            [string]$Rights
        )

        $ADObject = [ADSI]("LDAP://" + $TargetObject)
        $Identity = $SourceObject
        $ADRights = [System.DirectoryServices.ActiveDirectoryRights]$Rights
        $Type = [System.Security.AccessControl.AccessControlType] "Allow"
        $InheritanceType = [System.DirectoryServices.ActiveDirectorySecurityInheritance] "All"
        $ACE = New-Object System.DirectoryServices.ActiveDirectoryAccessRule $Identity, $ADRights, $Type, $InheritanceType
        $ADObject.psbase.ObjectSecurity.AddAccessRule($ACE)
        $ADObject.psbase.commitchanges()
}

function Set-BadACLs {

    <#
        .SYNOPSIS
            Creates vulnerable ACLs.

        .DESCRIPTION
            The function begins by granting the Chads group GenericAll rights on the Domain Admins. It then grants the Degens group GenericALl rights on the Chads group. Finally, it grants GenericAll rights on some users from the Degens group to some users of the Normies group.

        .EXAMPLE
            PS > Set-BadACLs -Verbose

            Create vulnerable ACLs and display verbose output.
    #>

    [CmdletBinding()]
    Param()
    
    Write-Verbose "Granting Chads GenericAll rights on Domain Admins..."

    $SourceObject = (Get-ADGroup -Identity "Chads").SID
    $TargetObject = (Get-ADGroup -Identity "Domain Admins").DistinguishedName
    Add-ACL -SourceObject $SourceObject -TargetObject $TargetObject -Rights "GenericAll"

    Write-Verbose "Granting Degens GenericAll rights on Chads"

    $SourceObject = (Get-ADGroup -Identity "Degens").SID
    $TargetObject = (Get-ADGroup -Identity "Chads").DistinguishedName
    Add-ACL -SourceObject $SourceObject -TargetObject $TargetObject -Rights "GenericAll"

    Write-Verbose "Granting some random Normies GenericAll rights on some Degens..."

    $UserCount = [Int]((Get-ADGroupMember -Identity Normies | Measure-Object).Count * (1/10))
    $SourceUsers = (Get-ADGroupMember -Identity "Normies" | Sort-Object { Get-Random } | Select -First $UserCount)
    $TargetUsers = (Get-ADGroupMember -Identity "Degens" | Sort-Object { Get-Random } | Select -First $UserCount)

    for($i = 0; $i -lt $UserCount; $i++) {
        Write-Verbose "Granting $($SourceUsers[$i].Name) GenericAll rights on $($TargetUsers[$i].Name)..."
        $SourceUser = $SourceUsers[$i].SID
        $TargetUser = $TargetUsers[$i].DistinguishedName
        Add-ACL -SourceObject $SourceUser -TargetObject $TargetUser -Rights "GenericAll"
    }
}
