Import-Module ActiveDirectory

# ============================================
# COLLECT INPUTS
# ============================================
$requestedGroupName = (Read-Host "Enter the Security Group name").Trim()

Write-Host ""
Write-Host "Enter the Employee IDs one per line." -ForegroundColor Yellow
Write-Host "When done, press ENTER on an empty line." -ForegroundColor Yellow
Write-Host ""

$employeeIds = @()
while ($true) {
    $input = (Read-Host "Employee ID").Trim()
    if ($input -eq "") { break }
    $employeeIds += $input
}

if ($employeeIds.Count -eq 0) {
    Write-Host ""
    Write-Host "ERROR: No Employee IDs entered. Process stopped." -ForegroundColor Red
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
    $beforeMembers = Get-ADGroupMember -Identity $exactGroupName -ErrorAction Stop |
                     Select-Object -ExpandProperty SamAccountName |
                     Sort-Object
}
catch {
    Write-Host ""
    Write-Host "ERROR: Could not retrieve current members of '$exactGroupName'." -ForegroundColor Red
    Write-Host "Reason: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Process stopped. No changes were made." -ForegroundColor Yellow
    exit
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Target Group    : $exactGroupName" -ForegroundColor Cyan
Write-Host " BEFORE - Current Members ($($beforeMembers.Count) total)" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
$beforeMembers | ForEach-Object { Write-Host "  - $_" }
Write-Host "============================================" -ForegroundColor Cyan

# ============================================
# PROCESS EACH EMPLOYEE ID
# ============================================
$successList       = @()
$alreadyMemberList = @()
$notFoundList      = @()
$failedList        = @()

foreach ($targetEmployeeId in $employeeIds) {
    try {
        $directoryUser = Get-ADUser -Identity $targetEmployeeId -ErrorAction Stop
    }
    catch {
        $notFoundList += $targetEmployeeId
        Write-Host ""
        Write-Host "  SKIPPED: Employee ID '$targetEmployeeId' not found in AD." -ForegroundColor Red
        continue
    }

    $isMember = $beforeMembers -icontains $targetEmployeeId
    if ($isMember) {
        $alreadyMemberList += $targetEmployeeId
        Write-Host ""
        Write-Host "  SKIPPED: '$targetEmployeeId' is already a member of '$exactGroupName'." -ForegroundColor Yellow
        continue
    }

    try {
        Add-ADGroupMember -Identity $exactGroupName -Members $targetEmployeeId -ErrorAction Stop
        $successList += $targetEmployeeId
        Write-Host ""
        Write-Host "  ADDED: '$targetEmployeeId' successfully added to '$exactGroupName'." -ForegroundColor Green
    }
    catch {
        $failedList += $targetEmployeeId
        Write-Host ""
        Write-Host "  FAILED: Could not add '$targetEmployeeId' to '$exactGroupName'." -ForegroundColor Red
        Write-Host "  Reason: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# ============================================
# PROCESSING RESULTS
# ============================================
Write-Host ""
Write-Host "============================================" -ForegroundColor Magenta
Write-Host " PROCESSING RESULTS" -ForegroundColor Magenta
Write-Host "============================================" -ForegroundColor Magenta

if ($successList.Count -gt 0) {
    Write-Host ""
    Write-Host " SUCCESSFULLY ADDED:" -ForegroundColor Green
    $successList | ForEach-Object { Write-Host "  + $_" -ForegroundColor Green }
}
if ($alreadyMemberList.Count -gt 0) {
    Write-Host ""
    Write-Host " ALREADY A MEMBER (skipped):" -ForegroundColor Yellow
    $alreadyMemberList | ForEach-Object { Write-Host "  = $_" -ForegroundColor Yellow }
}
if ($notFoundList.Count -gt 0) {
    Write-Host ""
    Write-Host " EMPLOYEE ID NOT FOUND IN AD (skipped):" -ForegroundColor Red
    $notFoundList | ForEach-Object { Write-Host "  x $_" -ForegroundColor Red }
}
if ($failedList.Count -gt 0) {
    Write-Host ""
    Write-Host " FAILED TO ADD (check permissions):" -ForegroundColor Red
    $failedList | ForEach-Object { Write-Host "  ! $_" -ForegroundColor Red }
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Magenta

# ============================================
# CHANGE SUMMARY
# ============================================
Write-Host ""
Write-Host "============================================" -ForegroundColor White
Write-Host " CHANGE SUMMARY" -ForegroundColor White
Write-Host "============================================" -ForegroundColor White
Write-Host " Target Group      : $exactGroupName" -ForegroundColor White
Write-Host " Users Requested   : $($employeeIds.Count)" -ForegroundColor White
Write-Host " Successfully Added: $($successList.Count)" -ForegroundColor Green
Write-Host " Already Member    : $($alreadyMemberList.Count)" -ForegroundColor Yellow
Write-Host " Not Found in AD   : $($notFoundList.Count)" -ForegroundColor Red
Write-Host " Failed            : $($failedList.Count)" -ForegroundColor Red
Write-Host " Performed by      : $env:userdomain\$env:username" -ForegroundColor White
Write-Host " Timestamp         : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
Write-Host "============================================" -ForegroundColor White
Write-Host ""
Write-Host "NOTE: Please verify the changes in ADUC - Members tab of the group." -ForegroundColor Gray

