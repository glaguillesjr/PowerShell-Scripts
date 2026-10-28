Import-Module ActiveDirectory

# ============================================
# COLLECT INPUT - EMPLOYEE ID
# ============================================
$targetEmployeeId = (Read-Host "Enter the Employee ID").Trim()

# ============================================
# VALIDATE USER EXISTS IN AD
# ============================================
try {
    $directoryUser = Get-ADUser -Identity $targetEmployeeId `
              -Properties UserPrincipalName, EmailAddress `
              -ErrorAction Stop
}
catch {
    Write-Host ""
    Write-Host "ERROR: Employee ID '$targetEmployeeId' not found in Active Directory." -ForegroundColor Red
    Write-Host "Reason: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Process stopped. No changes were made." -ForegroundColor Yellow
    exit
}

# ============================================
# DISPLAY MENU
# ============================================
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " SELECT RESET TYPE" -ForegroundColor Cyan
Write-Host " [1] Password Reset Only" -ForegroundColor Cyan
Write-Host " [2] MFA Reset Only" -ForegroundColor Cyan
Write-Host " [3] Password and MFA Reset" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
$choice = (Read-Host "Enter choice (1, 2 or 3)").Trim()

# ============================================
# VALIDATE CHOICE
# ============================================
if ($choice -ne "1" -and $choice -ne "2" -and $choice -ne "3") {
    Write-Host ""
    Write-Host "ERROR: Invalid choice '$choice'." -ForegroundColor Red
    Write-Host "Please enter 1, 2 or 3 only." -ForegroundColor Yellow
    Write-Host "Process stopped. No changes were made." -ForegroundColor Yellow
    exit
}

# ============================================
# INITIALIZE RESULT TRACKING
# ============================================
$passwordStatus    = "NOT ATTEMPTED"
$mfaStatus         = "NOT ATTEMPTED"
$temporaryPasswordPlainText = $null

# ============================================
# PASSWORD RESET
# ============================================
if ($choice -eq "1" -or $choice -eq "3") {

    Write-Host ""
    Write-Host "--- PASSWORD RESET ---" -ForegroundColor White

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

    try {
        Set-ADAccountPassword -Identity $targetEmployeeId `
            -NewPassword $temporaryPasswordSecureString -Reset -ErrorAction Stop
        Write-Host "  Password reset executed successfully." -ForegroundColor Green
        $passwordStatus = "SUCCESS"
    }
    catch {
        Write-Host ""
        Write-Host "ERROR: Password reset failed." -ForegroundColor Red
        Write-Host "Reason: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Process stopped." -ForegroundColor Yellow
        exit
    }

    try {
        Set-ADUser -Identity $targetEmployeeId `
            -ChangePasswordAtLogon $true -ErrorAction Stop
        Write-Host "  User will be required to change password on next login." -ForegroundColor Green
    }
    catch {
        Write-Host "  WARNING: Could not set ChangePasswordAtLogon flag." -ForegroundColor Yellow
        Write-Host "  Reason: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "  Password was reset but user may not be forced to change it." -ForegroundColor Yellow
    }
}

# ============================================
# MFA RESET
# ============================================
if ($choice -eq "2" -or $choice -eq "3") {

    Write-Host ""
    Write-Host "--- MFA RESET ---" -ForegroundColor White

    $upn = $directoryUser.UserPrincipalName

    if (-not $upn) {
        $upn = $directoryUser.EmailAddress
    }

    if (-not $upn) {
        Write-Host ""
        Write-Host "WARNING: No UPN or email found in AD for '$targetEmployeeId'." -ForegroundColor Yellow
        $upn = (Read-Host "  Please enter the user's email address manually").Trim()

        if (-not $upn) {
            Write-Host ""
            Write-Host "ERROR: Email address is required for MFA reset." -ForegroundColor Red
            Write-Host "Process stopped." -ForegroundColor Yellow
            exit
        }
    }

    Write-Host "  UPN resolved: $upn" -ForegroundColor Gray

    try {
        Write-Host "  Connecting to Microsoft Graph..." -ForegroundColor Gray
        Connect-MgGraph -Scopes "UserAuthenticationMethod.ReadWrite.All" `
            -ErrorAction Stop | Out-Null
        Write-Host "  Connected to Microsoft Graph successfully." -ForegroundColor Green
    }
    catch {
        Write-Host ""
        Write-Host "ERROR: Could not connect to Microsoft Graph." -ForegroundColor Red
        Write-Host "Reason: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Process stopped." -ForegroundColor Yellow
        exit
    }

    try {
        $mgUser = Get-MgUser -UserId $upn -ErrorAction Stop
        $directoryUserId = $mgUser.Id
        Write-Host "  User found in Azure AD: $upn" -ForegroundColor Green
    }
    catch {
        Write-Host ""
        Write-Host "ERROR: Could not find '$upn' in Azure AD." -ForegroundColor Red
        Write-Host "Reason: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Process stopped." -ForegroundColor Yellow
        Disconnect-MgGraph | Out-Null
        exit
    }

    try {
        $authMethods = Get-MgUserAuthenticationMethod `
            -UserId $directoryUserId -ErrorAction Stop
    }
    catch {
        Write-Host ""
        Write-Host "ERROR: Could not retrieve MFA methods for '$upn'." -ForegroundColor Red
        Write-Host "Reason: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Process stopped." -ForegroundColor Yellow
        Disconnect-MgGraph | Out-Null
        exit
    }

    $methodsRemoved = 0
    $methodsSkipped = 0

    foreach ($method in $authMethods) {

        $methodType = $method.AdditionalProperties["@odata.type"]
        $methodId   = $method.Id

        if ($methodType -eq "#microsoft.graph.passwordAuthenticationMethod") {
            $methodsSkipped++
            continue
        }

        try {
            switch ($methodType) {
                "#microsoft.graph.microsoftAuthenticatorAuthenticationMethod" {
                    Remove-MgUserAuthenticationMicrosoftAuthenticatorMethod `
                        -UserId $directoryUserId `
                        -MicrosoftAuthenticatorAuthenticationMethodId $methodId `
                        -ErrorAction Stop
                    Write-Host "  Removed: Microsoft Authenticator" -ForegroundColor Green
                    $methodsRemoved++
                }
                "#microsoft.graph.phoneAuthenticationMethod" {
                    Remove-MgUserAuthenticationPhoneMethod `
                        -UserId $directoryUserId `
                        -PhoneAuthenticationMethodId $methodId `
                        -ErrorAction Stop
                    Write-Host "  Removed: Phone Authentication" -ForegroundColor Green
                    $methodsRemoved++
                }
                "#microsoft.graph.emailAuthenticationMethod" {
                    Remove-MgUserAuthenticationEmailMethod `
                        -UserId $directoryUserId `
                        -EmailAuthenticationMethodId $methodId `
                        -ErrorAction Stop
                    Write-Host "  Removed: Email Authentication" -ForegroundColor Green
                    $methodsRemoved++
                }
                "#microsoft.graph.fido2AuthenticationMethod" {
                    Remove-MgUserAuthenticationFido2Method `
                        -UserId $directoryUserId `
                        -Fido2AuthenticationMethodId $methodId `
                        -ErrorAction Stop
                    Write-Host "  Removed: FIDO2 Security Key" -ForegroundColor Green
                    $methodsRemoved++
                }
                "#microsoft.graph.softwareOathAuthenticationMethod" {
                    Remove-MgUserAuthenticationSoftwareOathMethod `
                        -UserId $directoryUserId `
                        -SoftwareOathAuthenticationMethodId $methodId `
                        -ErrorAction Stop
                    Write-Host "  Removed: Software OATH Token" -ForegroundColor Green
                    $methodsRemoved++
                }
                "#microsoft.graph.windowsHelloForBusinessAuthenticationMethod" {
                    Write-Host "  SKIPPED: Windows Hello (cannot be removed remotely)" -ForegroundColor Yellow
                    $methodsSkipped++
                }
                default {
                    Write-Host "  SKIPPED: Unknown method type - $methodType" -ForegroundColor Yellow
                    $methodsSkipped++
                }
            }
        }
        catch {
            Write-Host "  WARNING: Could not remove method '$methodType'." -ForegroundColor Yellow
            Write-Host "  Reason: $($_.Exception.Message)" -ForegroundColor Yellow
            $methodsSkipped++
        }
    }

    if ($methodsRemoved -gt 0) {
        $mfaStatus = "SUCCESS - $methodsRemoved method(s) removed"
    }
    elseif ($methodsRemoved -eq 0 -and $methodsSkipped -gt 0) {
        $mfaStatus = "NO MFA METHODS FOUND - Nothing to remove"
    }
    else {
        $mfaStatus = "COMPLETED"
    }

    Write-Host "  User will be prompted to re-register MFA on next login." -ForegroundColor Green
    Disconnect-MgGraph | Out-Null
    Write-Host "  Disconnected from Microsoft Graph." -ForegroundColor Gray
}

# ============================================
# CHANGE SUMMARY
# ============================================
Write-Host ""
Write-Host "============================================" -ForegroundColor White
Write-Host " CHANGE SUMMARY" -ForegroundColor White
Write-Host "============================================" -ForegroundColor White
Write-Host " Employee ID   : $targetEmployeeId" -ForegroundColor White

switch ($choice) {
    "1" { Write-Host " Reset Type    : Password Reset Only" -ForegroundColor White }
    "2" { Write-Host " Reset Type    : MFA Reset Only" -ForegroundColor White }
    "3" { Write-Host " Reset Type    : Password and MFA Reset" -ForegroundColor White }
}

if ($choice -eq "1" -or $choice -eq "3") {
    Write-Host " Password Reset: $passwordStatus" -ForegroundColor Green
    Write-Host " Temp Password : $temporaryPasswordPlainText" -ForegroundColor Green
}

if ($choice -eq "2" -or $choice -eq "3") {
    Write-Host " MFA Reset     : $mfaStatus" -ForegroundColor Green
}

Write-Host " Performed by  : $env:userdomain\$env:username" -ForegroundColor White
Write-Host " Timestamp     : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
Write-Host "============================================" -ForegroundColor White
Write-Host ""

if ($choice -eq "1" -or $choice -eq "3") {
    Write-Host "NOTE: Forward the temporary password to the requestor." -ForegroundColor Gray
    Write-Host "      User must change password on next login." -ForegroundColor Gray
}
if ($choice -eq "2" -or $choice -eq "3") {
    Write-Host "NOTE: User will be prompted to re-register MFA on next login." -ForegroundColor Gray
}

