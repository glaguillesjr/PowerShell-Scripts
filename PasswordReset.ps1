Import-Module ActiveDirectory

# ============================================
# COLLECT INPUT
# ============================================
$targetEmployeeId = (Read-Host "Enter the Employee ID").Trim()

# ============================================
# VALIDATE USER EXISTS IN AD
# ============================================
try {
    $directoryUser = Get-ADUser -Identity $targetEmployeeId -ErrorAction Stop
}
catch {
    Write-Host ""
    Write-Host "ERROR: Employee ID '$targetEmployeeId' not found in Active Directory." -ForegroundColor Red
    Write-Host "Reason: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Process stopped. No changes were made." -ForegroundColor Yellow
    exit
}

# ============================================
# GENERATE RANDOM SECURE PASSWORD
# ============================================
$upper   = 'ABCDEFGHJKLMNPQRSTUVWXYZ'
$lower   = 'abcdefghijkmnpqrstuvwxyz'
$numbers = '23456789'
$special = '!@#$%'

$guaranteed = @(
    $upper[(Get-Random -Maximum $upper.Length)],
    $upper[(Get-Random -Maximum $upper.Length)],
    $lower[(Get-Random -Maximum $lower.Length)],
    $lower[(Get-Random -Maximum $lower.Length)],
    $numbers[(Get-Random -Maximum $numbers.Length)],
    $numbers[(Get-Random -Maximum $numbers.Length)],
    $special[(Get-Random -Maximum $special.Length)],
    $special[(Get-Random -Maximum $special.Length)]
)

$allChars = $upper + $lower + $numbers + $special
$remaining = (1..6) | ForEach-Object {
    $allChars[(Get-Random -Maximum $allChars.Length)]
}

$temporaryPasswordPlainText = -join ($guaranteed + $remaining | Sort-Object { Get-Random })
$temporaryPasswordSecureString = ConvertTo-SecureString $temporaryPasswordPlainText -AsPlainText -Force

# ============================================
# RESET PASSWORD IN AD
# ============================================
try {
    Set-ADAccountPassword -Identity $targetEmployeeId `
        -NewPassword $temporaryPasswordSecureString -Reset -ErrorAction Stop
}
catch {
    Write-Host ""
    Write-Host "ERROR: Password reset failed." -ForegroundColor Red
    Write-Host "Reason: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Process stopped. No changes were made." -ForegroundColor Yellow
    exit
}

# ============================================
# FORCE PASSWORD CHANGE ON NEXT LOGIN
# ============================================
try {
    Set-ADUser -Identity $targetEmployeeId `
        -ChangePasswordAtLogon $true -ErrorAction Stop
}
catch {
    Write-Host ""
    Write-Host "WARNING: Could not set ChangePasswordAtLogon flag." -ForegroundColor Yellow
    Write-Host "Reason: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "Password was reset but user may not be forced to change it." -ForegroundColor Yellow
}

# ============================================
# CHANGE SUMMARY
# ============================================
Write-Host ""
Write-Host "============================================" -ForegroundColor White
Write-Host " CHANGE SUMMARY" -ForegroundColor White
Write-Host "============================================" -ForegroundColor White
Write-Host " Employee ID   : $targetEmployeeId" -ForegroundColor White
Write-Host " Status        : SUCCESS" -ForegroundColor Green
Write-Host " Temp Password : $temporaryPasswordPlainText" -ForegroundColor Green
Write-Host " Performed by  : $env:userdomain\$env:username" -ForegroundColor White
Write-Host " Timestamp     : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
Write-Host "============================================" -ForegroundColor White
Write-Host ""
Write-Host "NOTE: Forward the temporary password to the requestor." -ForegroundColor Gray
Write-Host "      User must change password on next login." -ForegroundColor Gray

