# Auto-scaling Backend Diagnostic Script
# This script helps diagnose common deployment issues

param(
    [switch]$Detailed
)

Write-Host "Auto-scaling Backend Diagnostics" -ForegroundColor Cyan
Write-Host "===================================" -ForegroundColor Cyan

function Write-DiagnosticHeader {
    param([string]$Title)
    Write-Host ""
    Write-Host "$Title" -ForegroundColor Yellow
    Write-Host ("─" * ($Title.Length + 4)) -ForegroundColor Gray
}

function Test-Port {
    param([int]$Port, [string]$Service)
    try {
        $connection = Test-NetConnection -ComputerName localhost -Port $Port -WarningAction SilentlyContinue -InformationLevel Quiet
        if ($connection.TcpTestSucceeded) {
            Write-Host "   Port $Port ($Service): Available" -ForegroundColor Green
            return $true
        } else {
            Write-Host "   Port $Port ($Service): Not responding" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "   Port $Port ($Service): Cannot test" -ForegroundColor Yellow
        return $false
    }
}

# Check Docker
Write-DiagnosticHeader "Docker Status"
try {
    $dockerVersion = docker --version
    Write-Host "   Docker: $dockerVersion" -ForegroundColor Green
    
    $swarmStatus = docker info --format "{{.Swarm.LocalNodeState}}" 2>$null
    if ($swarmStatus -eq "active") {
        Write-Host "   Docker Swarm: Active" -ForegroundColor Green
    } else {
        Write-Host "   Docker Swarm: Not active" -ForegroundColor Red
    }
} catch {
    Write-Host "   Docker: Not available" -ForegroundColor Red
}

# Check Ports
Write-DiagnosticHeader "Port Status"
$portTests = @(
    @{Port=80; Service="Nginx Load Balancer"},
    @{Port=3000; Service="API Direct"},
    @{Port=5432; Service="PostgreSQL"},
    @{Port=6379; Service="Redis"},
    @{Port=8080; Service="Autoscaler Health"},
    @{Port=8090; Service="Metrics"}
)

foreach ($test in $portTests) {
    Test-Port -Port $test.Port -Service $test.Service | Out-Null
}

# Check Docker Services
Write-DiagnosticHeader "Docker Services"
try {
    $services = docker service ls --filter label=project=scalable-backend-production --format "table {{.Name}}`t{{.Replicas}}`t{{.Image}}" 2>$null
    if ($services) {
        Write-Host $services
    } else {
        Write-Host "   No auto-scaling services found" -ForegroundColor Red
        Write-Host "   Run: .\deploy-autoscaling.ps1" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   Cannot check Docker services" -ForegroundColor Red
}

# Check Service Health
Write-DiagnosticHeader "Service Health Checks"
$healthChecks = @(
    @{Url="http://localhost/api/health"; Name="API"},
    @{Url="http://localhost:8080/health"; Name="Autoscaler"},
    @{Url="http://localhost:8090/metrics"; Name="Metrics"}
)

foreach ($check in $healthChecks) {
    try {
        $response = Invoke-WebRequest -Uri $check.Url -TimeoutSec 3 -UseBasicParsing
        if ($response.StatusCode -eq 200) {
            Write-Host "   $($check.Name): Healthy" -ForegroundColor Green
        } else {
            Write-Host "   $($check.Name): Status $($response.StatusCode)" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "   $($check.Name): Not responding" -ForegroundColor Red
    }
}

# Detailed diagnostics
if ($Detailed) {
    Write-DiagnosticHeader "Detailed Service Logs (Last 10 lines)"
    
    $serviceNames = @(
        "scalable-backend-production_api",
        "scalable-backend-production_autoscaler",
        "scalable-backend-production_nginx",
        "scalable-backend-production_postgres",
        "scalable-backend-production_redis"
    )
    
    foreach ($serviceName in $serviceNames) {
        try {
            Write-Host ""
            Write-Host "${serviceName}:" -ForegroundColor Cyan
            docker service logs --tail 10 $serviceName 2>$null | ForEach-Object {
                Write-Host "   $_" -ForegroundColor Gray
            }
        } catch {
            Write-Host "   Cannot retrieve logs for $serviceName" -ForegroundColor Red
        }
    }
    
    Write-DiagnosticHeader "Container Resource Usage"
    try {
        docker stats --no-stream --format "table {{.Container}}`t{{.CPUPerc}}`t{{.MemUsage}}`t{{.MemPerc}}" 2>$null
    } catch {
        Write-Host "   Cannot retrieve container stats" -ForegroundColor Red
    }
}

# Recommendations
Write-DiagnosticHeader "Recommendations"

$recommendations = @()

# Check if any services are missing
try {
    $serviceCount = (docker service ls --filter label=project=scalable-backend-production --quiet 2>$null | Measure-Object).Count
    if ($serviceCount -eq 0) {
        $recommendations += "Run deployment: .\deploy-autoscaling.ps1"
    } elseif ($serviceCount -lt 5) {
        $recommendations += "Some services missing - try redeploying: .\deploy-autoscaling.ps1"
    }
} catch {}

# Check if ports are blocked
$blockedPorts = @()
foreach ($test in $portTests) {
    if (-not (Test-Port -Port $test.Port -Service $test.Service)) {
        $blockedPorts += $test.Port
    }
}

if ($blockedPorts.Count -gt 0) {
    $recommendations += "Ports not responding: $($blockedPorts -join ', ') - Check if services are running"
}

# Check API health
try {
    $apiResponse = Invoke-WebRequest -Uri "http://localhost/api/health" -TimeoutSec 3 -UseBasicParsing
    if ($apiResponse.StatusCode -ne 200) {
        $recommendations += "API not healthy - Check API logs: docker service logs scalable-backend-production_api"
    }
} catch {
    $recommendations += "API not responding - Check deployment and logs"
}

if ($recommendations.Count -eq 0) {
    Write-Host "Everything looks good!" -ForegroundColor Green
} else {
    foreach ($rec in $recommendations) {
        Write-Host "   $rec" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Quick Commands:" -ForegroundColor Cyan
Write-Host "   - View all services: docker service ls"
Write-Host "   - Check specific logs: docker service logs -f [service-name]"
Write-Host "   - Restart service: docker service update --force [service-name]"
Write-Host "   - Stop everything: docker stack rm scalable-backend-production"
Write-Host "   - Redeploy: .\deploy-autoscaling.ps1"
Write-Host "   - Detailed diagnostics: .\diagnose-autoscaling.ps1 -Detailed"

Write-Host ""
Write-Host "Diagnostic complete!" -ForegroundColor Green 