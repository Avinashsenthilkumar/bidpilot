# BidPilot deploy for Windows PowerShell
# Usage: powershell -ExecutionPolicy Bypass -File .\deploy.ps1 -Org bidpilot [-Push] [-Repo https://github.com/<user>/bidpilot.git]
param(
    [string]$Org = "bidpilot",
    [switch]$Push,
    [string]$Repo = "https://github.com/Avinashsenthilkumar/bidpilot.git",
    [switch]$SkipLogin
)

function Run($label, [scriptblock]$cmd, [switch]$AllowFail) {
    Write-Host "==> $label" -ForegroundColor Cyan
    & $cmd
    if ($LASTEXITCODE -ne 0 -and -not $AllowFail) {
        Write-Host "FAILED: $label (exit $LASTEXITCODE)" -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

Set-Location $PSScriptRoot

if (-not $SkipLogin) {
    $known = sf org display --target-org $Org 2>$null
    if ($LASTEXITCODE -ne 0) {
        Run "Logging in to Salesforce (browser will open)" { sf org login web --alias $Org }
    } else {
        Write-Host "==> Already logged in to $Org" -ForegroundColor Cyan
    }
}

Run "Deploying BidPilot metadata to $Org" { sf project deploy start --source-dir force-app --target-org $Org --wait 30 }
Run "Assigning BidPilot_User permission set" { sf org assign permset --name BidPilot_User --target-org $Org } -AllowFail
Run "Loading demo data" { sf apex run --file scripts/apex/seed.apex --target-org $Org }
Run "Running Apex tests" { sf apex run test --class-names BidPilotTests --code-coverage --result-format human --wait 15 --target-org $Org } -AllowFail

if ($Push) {
    if (-not (Test-Path .git)) { Run "git init" { git init } }
    Run "git add" { git add . }
    git diff --cached --quiet
    if ($LASTEXITCODE -ne 0) {
        Run "git commit" { git commit -m "BidPilot: Agentforce SOW-to-Proposal agent" }
    }
    Run "git branch main" { git branch -M main }
    git remote get-url origin 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) { Run "git remote add" { git remote add origin $Repo } }
    Run "git push" { git push -u origin main }
}

Write-Host ""
Write-Host "Done. Next: add BidPilot Dashboard to the Bid page and set up the agent (README sections 2 and 3)." -ForegroundColor Green
sf org open --target-org $Org --path "/lightning/o/Bid__c/list"
