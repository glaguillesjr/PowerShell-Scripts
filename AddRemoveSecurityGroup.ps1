Import-Module ActiveDirectory

# ============================================
# COLLECT INPUTS
# ============================================
$targetEmployeeId = (Read-Host "Enter the Employee ID of the user").Trim()
$requestedGroupName  = (Read-Host "Enter the Security Group name").Trim()
$action     = (Read-Host "Type ADD or REMOVE").Trim().ToUpper()

# ============================================
# VALIDATE ACTION
# ============================================
if ($action -ne "ADD" -and $action -ne "REMOVE") {
    Write-Host ""
    Write-Host "ERROR: Invalid action '$action'." -ForegroundColor Red
    Write-Host "Please type ADD or REMOVE only." -ForegroundColor Yellow
    exit
}

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
# VALIDATE GROUP EXISTS IN AD (case insensitive)
# ============================================
try {
    $resolvedGroup = Get-ADGroup -Filter { Name -like $requestedGroupName } -ErrorAction Stop
    if (-not $resolvedGroup) {
        Write-Host ""
        Write-Host "ERROR: Security Group '$requestedGroupName' not found in Active Directory." -ForegroundColor Red
        Write-Host "Process stopped. No changes were made." -ForegroundColor Yellow
        exit
    }
    $exactGroupName = $resolvedGroup.Name
}
catch {
    Write-Host ""
    Write-Host "ERROR: Security Group '$requestedGroupName' not found in Active Directory." -ForegroundColor Red
    Write-Host "Reason: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Process stopped. No changes were made." -ForegroundColor Yellow
    exit
}

# ============================================
# BEFORE SNAPSHOT
# ============================================
try {
    $beforeGroups = Get-ADPrincipalGroupMembership -Identity $targetEmployeeId -ErrorAction Stop |
                    Select-Object -ExpandProperty Name |
                    Sort-Object
}
catch {
    Write-Host ""
    Write-Host "ERROR: Could not retrieve current group memberships for '$targetEmployeeId'." -ForegroundColor Red
    Write-Host "Reason: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Process stopped. No changes were made." -ForegroundColor Yellow
    exit
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " BEFORE - Current Security Groups of $targetEmployeeId" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
$beforeGroups | ForEach-Object { Write-Host "  - $_" }
Write-Host "============================================" -ForegroundColor Cyan

# ============================================
# CHECK CURRENT MEMBERSHIP
# ============================================
try {
    $isMember = Get-ADGroupMember -Identity $exactGroupName -ErrorAction Stop |
                Where-Object { $_.SamAccountName -ieq $targetEmployeeId }
}
catch {
    Write-Host ""
    Write-Host "ERROR: Could not retrieve group members for '$exactGroupName'." -ForegroundColor Red
    Write-Host "Reason: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Process stopped. No changes were made." -ForegroundColor Yellow
    exit
}

# ============================================
# EXECUTE ADD OR REMOVE
# ============================================
if ($action -eq "ADD") {
    if ($isMember) {
        Write-Host ""
        Write-Host "WARNING: $targetEmployeeId is already a member of '$exactGroupName'." -ForegroundColor Yellow
        Write-Host "No changes were made." -ForegroundColor Yellow
        exit
    }
    else {
        try {
            Add-ADGroupMember -Identity $exactGroupName -Members $targetEmployeeId -ErrorAction Stop
        }
        catch {
            Write-Host ""
            Write-Host "ERROR: Failed to add $targetEmployeeId to '$exactGroupName'." -ForegroundColor Red
            Write-Host "Reason: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Process stopped. No changes were made." -ForegroundColor Yellow
            exit
        }
    }
}
elseif ($action -eq "REMOVE") {
    if (-not $isMember) {
        Write-Host ""
        Write-Host "WARNING: $targetEmployeeId is not a member of '$exactGroupName'." -ForegroundColor Yellow
        Write-Host "No changes were made." -ForegroundColor Yellow
        exit
    }
    else {
        try {
            Remove-ADGroupMember -Identity $exactGroupName -Members $targetEmployeeId -Confirm:$false -ErrorAction Stop
        }
        catch {
            Write-Host ""
            Write-Host "ERROR: Failed to remove $targetEmployeeId from '$exactGroupName'." -ForegroundColor Red
            Write-Host "Reason: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Process stopped. No changes were made." -ForegroundColor Yellow
            exit
        }
    }
}

# ============================================
# CHANGE SUMMARY
# ============================================
Write-Host ""
Write-Host "============================================" -ForegroundColor White
Write-Host " CHANGE SUMMARY" -ForegroundColor White
Write-Host "============================================" -ForegroundColor White
Write-Host " Employee ID : $targetEmployeeId" -ForegroundColor White
Write-Host " Group       : $exactGroupName" -ForegroundColor White
Write-Host " Action      : $action" -ForegroundColor White
Write-Host " Status      : SUCCESS" -ForegroundColor Green
Write-Host " Performed by: $env:userdomain\$env:username" -ForegroundColor White
Write-Host " Timestamp   : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
Write-Host "============================================" -ForegroundColor White
Write-Host ""
Write-Host "NOTE: Please verify the change in ADUC - Member Of tab." -ForegroundColor Gray

