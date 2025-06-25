# EXTREME STRESS TEST - Scalable Backend Maximum Capacity Test
# WARNING: This script will push your system to its limits!

param(
    [int]$MaxConcurrentUsers = 100,
    [int]$TestDurationMinutes = 5,
    [string]$BaseUrl = "http://localhost"
)

Write-Host "EXTREME STRESS TEST STARTING" -ForegroundColor Red -BackgroundColor Yellow
Write-Host "WARNING: This will push your backend to maximum capacity!" -ForegroundColor Yellow
Write-Host "Test Parameters:" -ForegroundColor Cyan
Write-Host "  Max Concurrent Users: $MaxConcurrentUsers" -ForegroundColor White
Write-Host "  Test Duration: $TestDurationMinutes minutes" -ForegroundColor White
Write-Host "  Target URL: $BaseUrl" -ForegroundColor White
Write-Host ""

# Phase 1: Health Check Bombardment
Write-Host "Phase 1: System Warm-up (Health Check Bombardment)" -ForegroundColor Yellow
$warmupJobs = @()

for ($i = 1; $i -le 50; $i++) {
    $warmupJobs += Start-Job -ScriptBlock {
        param($BaseUrl)
        
        for ($j = 1; $j -le 20; $j++) {
            try {
                Invoke-RestMethod -Uri "$BaseUrl/api/health" -TimeoutSec 10 | Out-Null
                Start-Sleep -Milliseconds (Get-Random -Maximum 100)
            } catch {
                # Continue on error
            }
        }
    } -ArgumentList $BaseUrl
}

Write-Host "  Executing 1,000 rapid health checks..." -ForegroundColor Cyan
$warmupJobs | Wait-Job | Remove-Job
Write-Host "  Warm-up complete!" -ForegroundColor Green

# Phase 2: User Registration
Write-Host "Phase 2: User Registration Tsunami" -ForegroundColor Red
$registrationJobs = @()

for ($i = 1; $i -le $MaxConcurrentUsers; $i++) {
    $registrationJobs += Start-Job -ScriptBlock {
        param($UserId, $BaseUrl, $Timestamp)
        
        $userData = @{
            email = "tsunami${UserId}_${Timestamp}@stresstest.com"
            username = "tsunamiuser${UserId}_${Timestamp}"
            password = "StressTest2024!"
        } | ConvertTo-Json
        
        try {
            $result = Invoke-RestMethod -Uri "$BaseUrl/api/users/register" -Method POST -Headers @{"Content-Type"="application/json"} -Body $userData -TimeoutSec 15
            return @{ Success = $true; UserId = $UserId; Data = $result; Email = "tsunami${UserId}_${Timestamp}@stresstest.com" }
        } catch {
            return @{ Success = $false; UserId = $UserId; Error = $_.Exception.Message }
        }
    } -ArgumentList $i, $BaseUrl, (Get-Date -Format "yyyyMMddHHmmss")
    
    if ($i % 10 -eq 0) {
        Start-Sleep -Milliseconds 500  # Increased delay between waves
        Write-Host "  Registration wave $([math]::Ceiling($i/10)) launched..." -ForegroundColor Cyan
    }
}

Write-Host "  Processing $MaxConcurrentUsers concurrent registrations..." -ForegroundColor Yellow
$regResults = $registrationJobs | Wait-Job | Receive-Job
$registrationJobs | Remove-Job

$successfulRegs = ($regResults | Where-Object Success -eq $true).Count
$failedRegs = ($regResults | Where-Object Success -eq $false).Count
Write-Host "  Registration Results: $successfulRegs succeeded, $failedRegs failed" -ForegroundColor White

# Show sample errors if registrations failed
if ($failedRegs -gt 0) {
    $sampleErrors = ($regResults | Where-Object Success -eq $false | Select-Object -First 3).Error
    Write-Host "  Sample errors:" -ForegroundColor Yellow
    foreach ($error in $sampleErrors) {
        Write-Host "    - $error" -ForegroundColor Red
    }
}

# Phase 3: Authentication
Write-Host "Phase 3: Authentication Storm" -ForegroundColor Red
Write-Host "  Waiting for database to stabilize..." -ForegroundColor Cyan
Start-Sleep -Seconds 5  # Give database time to commit all registrations

$loginJobs = @()
$successfulUsers = $regResults | Where-Object Success -eq $true | Select-Object -First 50

foreach ($user in $successfulUsers) {
    $loginJobs += Start-Job -ScriptBlock {
        param($UserEmail, $UserId, $BaseUrl)
        
        $loginData = @{
            email = $UserEmail
            password = "StressTest2024!"
        } | ConvertTo-Json
        
        try {
            $result = Invoke-RestMethod -Uri "$BaseUrl/api/users/login" -Method POST -Headers @{"Content-Type"="application/json"} -Body $loginData -TimeoutSec 15
            return @{ Success = $true; Token = $result.token; UserId = $UserId }
        } catch {
            return @{ Success = $false; UserId = $UserId; Error = $_.Exception.Message }
        }
    } -ArgumentList $user.Email, $user.UserId, $BaseUrl
}

Write-Host "  Executing rapid authentication for $($loginJobs.Count) users..." -ForegroundColor Cyan
$loginResults = $loginJobs | Wait-Job | Receive-Job
$loginJobs | Remove-Job

$authTokens = $loginResults | Where-Object Success -eq $true
Write-Host "  Obtained $($authTokens.Count) authentication tokens" -ForegroundColor Green

# Phase 4: Maximum Load
Write-Host "Phase 4: MAXIMUM LOAD - Task Creation Apocalypse" -ForegroundColor Red -BackgroundColor Yellow
$apocalypseJobs = @()

foreach ($tokenData in $authTokens) {
    $apocalypseJobs += Start-Job -ScriptBlock {
        param($Token, $UserId, $BaseUrl, $DurationMinutes)
        
        $authHeaders = @{
            "Content-Type" = "application/json"
            "Authorization" = "Bearer $Token"
        }
        
        $sessionStart = Get-Date
        $requestCount = 0
        $successCount = 0
        $errorCount = 0
        
        while (((Get-Date) - $sessionStart).TotalMinutes -lt $DurationMinutes) {
            # Burst of task creation
            for ($i = 1; $i -le 10; $i++) {
                try {
                    $taskData = @{
                        title = "Apocalypse Task $i by User $UserId"
                        description = "Maximum load stress test task"
                        priority = @("low", "medium", "high", "urgent")[(Get-Random -Maximum 4)]
                        status = "pending"
                    } | ConvertTo-Json
                    
                    Invoke-RestMethod -Uri "$BaseUrl/api/tasks" -Method POST -Headers $authHeaders -Body $taskData -TimeoutSec 10 | Out-Null
                    $successCount++
                } catch {
                    $errorCount++
                }
                $requestCount++
            }
            
            # Burst of task queries
            for ($i = 1; $i -le 15; $i++) {
                try {
                    $pageParam = "page=$i"
                    $limitParam = "limit=10"
                    $uri = "$BaseUrl/api/tasks?$pageParam" + "&" + "$limitParam"
                    Invoke-RestMethod -Uri $uri -Headers $authHeaders -TimeoutSec 10 | Out-Null
                    $successCount++
                } catch {
                    $errorCount++
                }
                $requestCount++
            }
            
            # Profile and stats spam
            for ($i = 1; $i -le 20; $i++) {
                try {
                    $action = $i % 3
                    if ($action -eq 0) {
                        Invoke-RestMethod -Uri "$BaseUrl/api/users/profile" -Headers $authHeaders -TimeoutSec 10 | Out-Null
                    } elseif ($action -eq 1) {
                        Invoke-RestMethod -Uri "$BaseUrl/api/tasks/stats/summary" -Headers $authHeaders -TimeoutSec 10 | Out-Null
                    } else {
                        Invoke-RestMethod -Uri "$BaseUrl/api/health/detailed" -TimeoutSec 10 | Out-Null
                    }
                    $successCount++
                } catch {
                    $errorCount++
                }
                $requestCount++
            }
            
            Start-Sleep -Milliseconds (Get-Random -Maximum 50)
        }
        
        return @{
            UserId = $UserId
            TotalRequests = $requestCount
            Successful = $successCount
            Errors = $errorCount
            Duration = ((Get-Date) - $sessionStart).TotalSeconds
        }
    } -ArgumentList $tokenData.Token, $tokenData.UserId, $BaseUrl, $TestDurationMinutes
}

Write-Host "  LAUNCHING MAXIMUM LOAD ATTACK!" -ForegroundColor Red
Write-Host "  $($apocalypseJobs.Count) concurrent users performing maximum operations" -ForegroundColor Yellow
Write-Host "  Duration: $TestDurationMinutes minutes" -ForegroundColor Yellow
Write-Host "  Expected load: 1000+ requests per minute per user" -ForegroundColor Yellow

# Real-time monitoring
$monitorStart = Get-Date
while (((Get-Date) - $monitorStart).TotalMinutes -lt $TestDurationMinutes) {
    $runningJobs = $apocalypseJobs | Where-Object State -eq "Running"
    $completedJobs = $apocalypseJobs | Where-Object State -eq "Completed"
    $failedJobs = $apocalypseJobs | Where-Object State -eq "Failed"
    
    $elapsed = [math]::Round(((Get-Date) - $monitorStart).TotalMinutes, 1)
    Write-Host "APOCALYPSE STATUS [$elapsed/$TestDurationMinutes min]: $($runningJobs.Count) active, $($completedJobs.Count) done, $($failedJobs.Count) failed" -ForegroundColor Red
    
    Start-Sleep -Seconds 5
}

Write-Host "STOPPING THE APOCALYPSE..." -ForegroundColor Red

# Collect results
Write-Host "Collecting job results..." -ForegroundColor Cyan
$apocalypseResults = @()
foreach ($job in $apocalypseJobs) {
    try {
        $jobResult = $job | Wait-Job | Receive-Job
        if ($jobResult) {
            $apocalypseResults += $jobResult
        }
    } catch {
        Write-Host "  Job $($job.Id) failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}
$apocalypseJobs | Remove-Job

Write-Host "Collected results from $($apocalypseResults.Count) successful jobs" -ForegroundColor Cyan

# Debug: Show what we actually got
if ($apocalypseResults.Count -gt 0) {
    Write-Host "  Debug: Sample result structure:" -ForegroundColor Magenta
    $sampleResult = $apocalypseResults[0]
    Write-Host "    Type: $($sampleResult.GetType().Name)" -ForegroundColor Gray
    if ($sampleResult -is [hashtable] -or $sampleResult -is [PSCustomObject]) {
        $sampleResult | Format-List | Out-String | Write-Host -ForegroundColor Gray
    } else {
        Write-Host "    Content: $sampleResult" -ForegroundColor Gray
    }
}

# Phase 5: Recovery Test
Write-Host "Phase 5: System Recovery Test" -ForegroundColor Yellow
Start-Sleep -Seconds 5

$recoveryTests = @()
for ($i = 1; $i -le 10; $i++) {
    try {
        $result = Invoke-RestMethod -Uri "$BaseUrl/api/health/detailed" -TimeoutSec 30
        $recoveryTests += @{ Success = $true; Response = $result }
    } catch {
        $recoveryTests += @{ Success = $false; Error = $_.Exception.Message }
    }
    Start-Sleep -Seconds 1
}

$recoveryRate = ($recoveryTests | Where-Object Success -eq $true).Count / $recoveryTests.Count * 100

# Final Statistics
Write-Host ""
Write-Host "EXTREME STRESS TEST RESULTS" -ForegroundColor Red -BackgroundColor Yellow
Write-Host "===========================================" -ForegroundColor Red
Write-Host ""

# Check if we have valid results and calculate totals
if ($apocalypseResults -and $apocalypseResults.Count -gt 0) {
    $totalRequests = 0
    $totalSuccessful = 0
    $totalErrors = 0
    
    foreach ($result in $apocalypseResults) {
        if ($result -is [hashtable]) {
            if ($result.ContainsKey("TotalRequests")) { $totalRequests += [int]$result["TotalRequests"] }
            if ($result.ContainsKey("Successful")) { $totalSuccessful += [int]$result["Successful"] }
            if ($result.ContainsKey("Errors")) { $totalErrors += [int]$result["Errors"] }
        } elseif ($null -ne $result.TotalRequests) {
            $totalRequests += [int]$result.TotalRequests
            $totalSuccessful += [int]$result.Successful
            $totalErrors += [int]$result.Errors
        }
    }
    
    Write-Host "  Successfully processed $($apocalypseResults.Count) job results" -ForegroundColor Green
} else {
    Write-Host "WARNING: No valid results from apocalypse phase - jobs may have failed" -ForegroundColor Red
    $totalRequests = 0
    $totalSuccessful = 0
    $totalErrors = 0
}

Write-Host "LOAD TEST STATISTICS:" -ForegroundColor Cyan
Write-Host "  Test Duration: $TestDurationMinutes minutes" -ForegroundColor White
Write-Host "  Concurrent Users: $($authTokens.Count)" -ForegroundColor White
Write-Host "  Total Requests: $totalRequests" -ForegroundColor White
Write-Host "  Successful Requests: $totalSuccessful" -ForegroundColor Green
Write-Host "  Failed Requests: $totalErrors" -ForegroundColor Red

if ($totalRequests -gt 0) {
    $successRate = ($totalSuccessful / $totalRequests) * 100
    $requestsPerSecond = $totalRequests / ($TestDurationMinutes * 60)
    $requestsPerUserPerMinute = $totalRequests / $authTokens.Count / $TestDurationMinutes
    
    Write-Host "  Success Rate: $([math]::Round($successRate, 2))%" -ForegroundColor Yellow
    Write-Host "  Requests/Second: $([math]::Round($requestsPerSecond, 2))" -ForegroundColor Yellow
    Write-Host "  Requests/User/Minute: $([math]::Round($requestsPerUserPerMinute, 2))" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "SYSTEM HEALTH:" -ForegroundColor Cyan
Write-Host "  User Registration Success: $([math]::Round(($successfulRegs / $MaxConcurrentUsers) * 100, 2))%" -ForegroundColor White
if ($successfulRegs -gt 0) {
    Write-Host "  Authentication Success: $([math]::Round(($authTokens.Count / $successfulRegs) * 100, 2))%" -ForegroundColor White
}
Write-Host "  Post-Test Recovery Rate: $([math]::Round($recoveryRate, 2))%" -ForegroundColor White

# Final system check
Write-Host ""
Write-Host "FINAL SYSTEM STATUS:" -ForegroundColor Cyan
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"

Write-Host ""
Write-Host "STRESS TEST VERDICT:" -ForegroundColor Green -BackgroundColor Black
if ($totalRequests -gt 0) {
    $successRate = ($totalSuccessful / $totalRequests)
    if ($recoveryRate -gt 80 -and $successRate -gt 0.7) {
        Write-Host "YOUR BACKEND IS A BEAST! It survived the apocalypse!" -ForegroundColor Green
    } elseif ($recoveryRate -gt 50) {
        Write-Host "Your backend is resilient but has room for optimization" -ForegroundColor Yellow
    } else {
        Write-Host "Your backend needs performance tuning for high loads" -ForegroundColor Red
    }
} else {
    Write-Host "Test incomplete - check system status and try again" -ForegroundColor Red
}

Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Yellow
Write-Host "  Analyze logs: docker-compose logs api | grep ERROR" -ForegroundColor White
Write-Host "  Check database performance: docker-compose exec postgres psql -U postgres -c 'SELECT count(*) FROM pg_stat_activity;'" -ForegroundColor White
Write-Host "  Monitor Redis cache: docker-compose exec redis redis-cli info stats" -ForegroundColor White
Write-Host "  Consider horizontal scaling if needed" -ForegroundColor White

Write-Host ""
Write-Host "EXTREME STRESS TEST COMPLETED!" -ForegroundColor Red -BackgroundColor Yellow