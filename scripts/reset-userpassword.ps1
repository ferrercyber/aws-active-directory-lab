function Reset-UserPassword {
    param(
        [Parameter(Mandatory=$true)][string]$Username,
        [string]$TempPassword = "TempPass!2026"
    )

    try {
        $user = Get-ADUser -Identity $Username -ErrorAction Stop

        Set-ADAccountPassword -Identity $Username `
            -NewPassword (ConvertTo-SecureString $TempPassword -AsPlainText -Force) `
            -Reset

        Set-ADUser -Identity $Username -ChangePasswordAtLogon $true

        Write-Host "Password reset for $($user.Name). Temporary password: $TempPassword" -ForegroundColor Green
        Write-Host "User must change password at next logon." -ForegroundColor Yellow
    }
    catch {
        Write-Host "ERROR: User '$Username' not found." -ForegroundColor Red
    }
}

# Usage examples:
# Reset-UserPassword -Username "ajohnson"
# Reset-UserPassword -Username "mlee" -TempPassword "CustomTemp!99"