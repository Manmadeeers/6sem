# load_test.ps1
$gateway = "http://localhost:5065/lb"
$methods = @("GET","POST","PUT","DELETE")
$results = @()
$errors = 0
$start = Get-Date

foreach ($method in $methods) {
    for ($i = 1; $i -le 50; $i++) {
        try {
            $resp = Invoke-RestMethod -Method $method -Uri $gateway -ErrorAction Stop
            $results += [pscustomobject]@{ Nick = $resp.nick; Method = $resp.method }
        } catch {
            $errors++
            Write-Warning "Failure at $method : $_"
        }
    }
}
$duration = (Get-Date) - $start

$counts = @{}
foreach ($r in $results) {
    $nick = $r.Nick
    if (-not $counts.ContainsKey($nick)) { $counts[$nick] = 0 }
    $counts[$nick] += 1
}

Write-Host ""
Write-Host "Total requests: $($methods.Count * 50) (for corresponding methods: 50 for each)"
Write-Host "Duration: $duration"
Write-Host "Errors: $errors"
Write-Host "Nick requests (Downstream):"
foreach ($nick in $counts.Keys) {
    Write-Host "  $nick : $($counts[$nick])"
}

$perMethod = @{}
foreach ($r in $results) {
    $key = "$($r.Method)|$($r.Nick)"
    if (-not $perMethod.ContainsKey($key)) { $perMethod[$key] = 0 }
    $perMethod[$key] += 1
}
Write-Host ""
Write-Host "Decompositions (method|Nick : number):"
foreach ($k in $perMethod.Keys) {
    Write-Host "  $k : $($perMethod[$k])"
}