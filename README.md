# ADLab PowerShell Module

## Introduction

The purpose of this module is to automate the deployment of an Active Directory lab for practicing internal penetration testing.

---

## Instructions

### Preparation

#### Optional but recommended: Move Module into `PSModulePath`

```powershell
# Display PSModulePath
$env:PSModulePath.split(";")

# Move module to path
Move-Item .\ADLab\ "C:\Windows\system32\WindowsPowerShell\v1.0\Modules\"
```

#### Import-Module

```powershell
# Import global module
Import-Module ADLab

# Import local module
Import-Module .\ADLab.psm1
```

---

### Initial Lab Setup

#### Invoke-DCPrep

This function prepares the current VM/computer to be used as a domain controller for the new forest. It sets a static IP address, sets the DNS server to be the localhost and renames the computer.

```powershell
# Prepare the current VM with all default values while displaying verbose output
Invoke-DCPrep -Verbose

# Set custom hostname and use Google DNS for Internet access
Invoke-DCPrep -Hostname "DC" -NewIPv4DNSServer "8.8.8.8"

# Use custom IP and default gateway and display verbose output
Invoke-DCPrep -Verbose -NewIPv4Address "192.168.1.99" -NewIPv4Gateway "192.168.1.1"
```

#### Invoke-ForestDeploy

The function installs the AD DS feature and sets up a new Active Directory forest, without requiring any user input. Restarts the computer upon completion.

```powershell
# Installs a new forest with FQDN of "bufu-sec.local" with default DSRM password of "Password!"
Invoke-ForestDeploy -Domain bufu-sec.local

# Installs a new forest with FQDN of "bufu-sec.local" with the DSRM password set to "P@ssword!" and displaying debug messages
Invoke-ForestDeploy -Domain "bufu-sec.local" -DSRMPassword "P@ssword!" -Verbose
```

#### Invoke-DNSDeploy

The function begins by installing the DNS feature. It then adds the primary zone and configures the server forwarder.

```powershell
# Install and configure DNS on the current host and display verbose output.
Invoke-DNSDeploy -Verbose -NetworkID 192.168.47.0/24 -ZoneFile "192.168.47.2.in-addr.arpa.dns" -ServerForwarder 1.1.1.1
```

#### Invoke-DHCPDeploy

The function begins by installing the DHCP feature on the current machine. It then adds the necesarry security groups and authorizes the new DHCP server with the domain controller. Finally, it configures the new DHCP scope with the supplied values.

```powershell
# Install and configure DHCP on the local DC.
Invoke-DHCPDeploy -Verbose -ScopeName Default -ScopeID 192.168.47.0 -StartIP 192.168.47.100 -EndIP 192.168.47.200 -SubnetMask 255.255.255.0 -DNSServer 192.168.47.10 -Router 192.168.47.10

# Install and configure DHCP on the specified DC.
Invoke-DHCPDeploy -Verbose -ScopeName Default -ScopeID 192.168.47.0 -StartIP 192.168.47.100 -EndIP 192.168.47.200 -SubnetMask 255.255.255.0 -DNSServer 192.168.47.10 -Router 192.168.47.10 -DCFQDN DC01.bufu-sec.local
```

---

### Content

#### Invoke-ADLabFill

The function begins by creating the groups and OUs defined in the global Groups variable. It then generates 10 user objects for each OU by default.

```powershell
# Fill forest with objects and display verbose output
Invoke-ADLabConfig -Verbose

# Create 50 users for each OU and display verbose output
Invoke-ADLabConfig -Verbose -UserCount 50
```

---

### Attack Vectors

#### Set-ASREPRoasting

The function gets a certain amount of random user from the domain and sets the DoesNotRequirePreAuth flag for each. Excludes default accounts like Administrator and krbtgt. Makes 5% of users ASREP-Roastable by default.

```powershell
# Make 5% of users ASREP-Roastable and display verbose output
Set-ASREPRoasting -Verbose

# Make 10 random users in the domain ASREP-Roastable
Set-ASREPRoasting -VulnerableUsersCount 10

# Make user bufu ASREP-Roastable and display verbose output
Set-ASREPRoasting -Users bufu -Verbose

# Make supplied list of users ASREP-roastable and display verbose output
Set-ASREPRoasting -Users ("bufu", "pepe") -Verbose
```

#### Set-Kerberoasting

The function gets a certain amount of random user from the domain and adds a SPN for each. Excludes default accounts like Administrator and krbtgt. Makes 5% of users kerberoastable by default.

```powershell
# Make 5% of users ASREP-Roastable and display verbose output
Set-Kerberoasting -Verbose

# Make 10 random users in the domain ASREP-Roastable
Set-Kerberoasting -VulnerableUsersCount 10

# Make user bufu ASREP-Roastable and display verbose output
Set-Kerberoasting -Users bufu -Verbose

# Make supplied list of users ASREP-roastable and display verbose output
Set-Kerberoasting -Users ("bufu", "pepe") -Verbose
```

#### Set-BadACLs

The function begins by granting the Chads group GenericAll rights on the Domain Admins. It then grants the Degens group GenericALl rights on the Chads group. Finally, it grants GenericAll rights on some users from the Degens group to some users of the Normies group.

```powershell
# Create vulnerable ACLs and display verbose output
Set-BadACLs -Verbose
```

#### Set-PSRemoting

The function first configures GPO to allow WinRM over TCP port 5985 to domain-joined systems. It then enables PS Remoting through GPO.

```powershell
# Enable PS Remoting and display verbose output
Set-PSRemoting -Verbose
```
