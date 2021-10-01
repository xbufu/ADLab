<#
Import this module to use all the setup commands in the current PowerShell session. The module must reside in the ADLab folder.

PS > Import-Module .\ADLab.psm1
#>

if(!$PSScriptRoot) { 
    $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
}

if ($PSVersionTable.PSVersion.Major -eq 2)
{
    #Code stolen from here https://github.com/mattifestation/PowerSploit
    Get-ChildItem -Recurse $PSScriptRoot *.ps1 | ForEach-Object  {Import-Module $_.FullName -DisableNameChecking}
} else {
    Get-ChildItem -Recurse $PSScriptRoot *.ps1 | ForEach-Object  {Import-Module $_.FullName -DisableNameChecking}
}