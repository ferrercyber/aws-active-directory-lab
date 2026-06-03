# Test-AccountLockout.ps1
# -----------------------------------------------------------------------------
# Triggers a deliberate account lockout for testing/demonstration purposes.
# Useful for verifying GPO lockout policy enforcement or testing HelpDesk
# runbooks.
#
# DO NOT run against production accounts.
#
# Usage examples:
#   .\Test-AccountLockout.ps1 -Username ajohnson
#   .\Test-AccountLockout.ps1 -Username ajohnson -AttemptCount 10
# -----------------------------------------------------------------------------

param(
    [Parameter(Mandatory=$true)][string]$Username,
    [int]$AttemptCount = 7
)

Write-Host "Triggering lockout simulation for $Username..." -ForegroundColor Yellow
Write-Host "Sending $AttemptCount failed authentication attempts." -ForegroundColor Yellow
Write-Host ""

1..$AttemptCount | ForEach-Object {
    try {
        $cred = New-Object System.Management.Automation.PSCredential(
            "$env:USERDOMAIN\$Username",
            (ConvertTo-SecureString "WrongPass$_" -AsPlainText -Force)
        )
        Start-Process -FilePath "powershell.exe" `
            -ArgumentList "-Command", "exit" `
            -Credential $cred `
            -ErrorAction Stop 2>$null
    } catch { }
    Start-Sleep -Seconds 1
}

Write-Host "Attempts complete. Current account state:" -ForegroundColor Cyan
Get-ADUser $Username -Properties LockedOut, badPwdCount | `
    Select-Object Name, LockedOut, badPwdCount | Format-Table -AutoSize

Write-Host ""
Write-Host "If LockedOut shows False but badPwdCount is below the threshold," -ForegroundColor Gray
Write-Host "the lockout policy may need a few minutes to fully propagate." -ForegroundColor Gray
Write-Host "Run 'gpupdate /force' on the DC and try again." -ForegroundColor Gray
