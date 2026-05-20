$domainname = ""
$domainUsername = "avds"
$domainPassword =  ""
$securePass = ConvertTo-SecureString $domainPassword -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential ("$domainname\$domainUsername", $securePass)
 
 
#Disable IE Enhanced Security Configuration (IE ESC)
$AdminKey = 'HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}'
$UserKey = 'HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}'
Set-ItemProperty -Path $AdminKey -Name 'IsInstalled' -Value 0
Set-ItemProperty -Path $UserKey -Name 'IsInstalled' -Value 0
 
# Disable automatic time zone update
Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation' -Name 'AutoTimeZoneUpdate' -Value 0
 
# Disable Windows Defender Firewall
Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled False
 
# Enable remote management
Configure-SMRemoting.exe -Enable
 
 
# Join VM to the domain
Add-Computer -DomainName "domain.cloud.local" -Credential $cred -Force -Restart
