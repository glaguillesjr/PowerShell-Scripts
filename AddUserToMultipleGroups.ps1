Import-Module ActiveDirectory

# ============================================
# COLLECT INPUTS
# ============================================
$targetEmployeeId = (Read-Host "Enter the Employee ID of the user").Trim()

Write-Host ""
Write-Host "Enter the Security Group names one per line." -ForegroundColor Yellow
Write-Host "When done, press ENTER on an empty line." -ForegroundColor Yellow
Write-Host ""

$requestedGroupNames = @()
while ($true) {
    $input = (Read-Host "Security Group").Trim()
    if ($input -eq "") { break }
    $requestedGroupNames += $input
}

if ($requestedGroupNames.Count -eq 0) {
    Write-Host ""
    Write-Host "ERROR: No security groups entered. Process stopped." -ForegroundColor Red
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
# PROCESS EACH GROUP
# ============================================
$successList       = @()
$alreadyMemberList = @()
$notFoundList      = @()
$failedList        = @()

foreach ($requestedGroupName in $requestedGroupNames) {
    try {
        $resolvedGroup = Get-ADGroup -Filter { Name -like $requestedGroupName } -ErrorAction Stop
        if (-not $resolvedGroup) {
            $notFoundList += $requestedGroupName
            Write-Host ""
            Write-Host "  SKIPPED: Group '$requestedGroupName' not found in AD." -ForegroundColor Red
            continue
        }
        $exactGroupName = $resolvedGroup.Name
    }
    catch {
        $notFoundList += $requestedGroupName
        Write-Host ""
        Write-Host "  SKIPPED: Group '$requestedGroupName' not found in AD." -ForegroundColor Red
        continue
    }

    try {
        $isMember = Get-ADGroupMember -Identity $exactGroupName -ErrorAction Stop |
                    Where-Object { $_.SamAccountName -ieq $targetEmployeeId }
    }
    catch {
        $failedList += $exactGroupName
        Write-Host ""
        Write-Host "  FAILED: Could not check membership for '$exactGroupName'." -ForegroundColor Red
        continue
    }

    if ($isMember) {
        $alreadyMemberList += $exactGroupName
        Write-Host ""
        Write-Host "  SKIPPED: '$targetEmployeeId' is already a member of '$exactGroupName'." -ForegroundColor Yellow
        continue
    }

    try {
        Add-ADGroupMember -Identity $exactGroupName -Members $targetEmployeeId -ErrorAction Stop
        $successList += $exactGroupName
        Write-Host ""
        Write-Host "  ADDED: '$targetEmployeeId' successfully added to '$exactGroupName'." -ForegroundColor Green
    }
    catch {
        $failedList += $exactGroupName
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
    Write-Host " GROUP NOT FOUND IN AD (skipped):" -ForegroundColor Red
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
Write-Host " Employee ID       : $targetEmployeeId" -ForegroundColor White
Write-Host " Groups Requested  : $($requestedGroupNames.Count)" -ForegroundColor White
Write-Host " Successfully Added: $($successList.Count)" -ForegroundColor Green
Write-Host " Already Member    : $($alreadyMemberList.Count)" -ForegroundColor Yellow
Write-Host " Not Found in AD   : $($notFoundList.Count)" -ForegroundColor Red
Write-Host " Failed            : $($failedList.Count)" -ForegroundColor Red
Write-Host " Performed by      : $env:userdomain\$env:username" -ForegroundColor White
Write-Host " Timestamp         : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
Write-Host "============================================" -ForegroundColor White
Write-Host ""
Write-Host "NOTE: Please verify the changes in ADUC - Member Of tab." -ForegroundColor Gray

