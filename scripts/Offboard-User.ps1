# Offboard-User.ps1
# Usage: change $username variable below, then run

$username = "lmartinez"

# 1. Disable the account
Disable-ADAccount -Identity $username

# 2. Reset password to random string (no one can use the account even if re-enabled)
$randomPass = -join ((33..126) | Get-Random -Count 20 | ForEach-Object { [char]$_ })
Set-ADAccountPassword -Identity $username `
    -NewPassword (ConvertTo-SecureString $randomPass -AsPlainText -Force) `
    -Reset

# 3. Remove from all groups (preserves "Domain Users" membership which is mandatory)
Get-ADUser -Identity $username -Properties MemberOf | `
    Select-Object -ExpandProperty MemberOf | `
    ForEach-Object { Remove-ADGroupMember -Identity $_ -Members $username -Confirm:$false }

# 4. Move to Disabled Users OU
Get-ADUser -Identity $username | Move-ADObject -TargetPath "OU=Disabled Users,DC=ferrercyber,DC=local"

# 5. Update description with offboarding date
Set-ADUser -Identity $username -Description "Offboarded $(Get-Date -Format 'yyyy-MM-dd')"

Write-Host "User $username offboarded successfully." -ForegroundColor Green
Write-Host "Account disabled, password scrambled, groups removed, moved to Disabled Users OU." -ForegroundColor Cyan