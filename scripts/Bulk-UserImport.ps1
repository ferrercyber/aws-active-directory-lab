# Bulk-UserImport.ps1
# -----------------------------------------------------------------------------
# Imports users from a CSV file and creates them in Active Directory.
# Each user is placed in the correct departmental OU based on the CSV.
#
# CSV format expected:
#   FirstName,LastName,Username,Department,OU
#
# Usage:
#   1. Update the CSV path below if needed
#   2. Run as Administrator on a domain controller (or machine with RSAT)
# -----------------------------------------------------------------------------

$users = Import-Csv "C:\Users\Administrator\Desktop\new_hires.csv"

foreach ($u in $users) {
    $ouPath = "OU=$($u.OU),OU=Employees,DC=ferrercyber,DC=local"
    $upn    = "$($u.Username)@ferrercyber.local"
    $displayName = "$($u.FirstName) $($u.LastName)"

    New-ADUser `
        -Name $displayName `
        -GivenName $u.FirstName `
        -Surname $u.LastName `
        -SamAccountName $u.Username `
        -UserPrincipalName $upn `
        -Path $ouPath `
        -Department $u.Department `
        -AccountPassword (ConvertTo-SecureString "Welcome!2026" -AsPlainText -Force) `
        -ChangePasswordAtLogon $true `
        -Enabled $true

    Write-Host "Created: $displayName in $($u.OU)" -ForegroundColor Green
}
