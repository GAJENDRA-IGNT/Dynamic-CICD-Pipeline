param(
    [Parameter(Mandatory = $true)]
    [string]$ClientId,

    [Parameter(Mandatory = $true)]
    [string]$ClientSecret,

    [Parameter(Mandatory = $true)]
    [string]$TenantId,

    [Parameter(Mandatory = $true)]
    [string]$WorkspaceId,

    [Parameter(Mandatory = $true)]
    [string]$ReportPath
)

Write-Host "============================================"
Write-Host "Publishing Power BI Report"
Write-Host "============================================"
Write-Host "Report Path  : $ReportPath"
Write-Host "Workspace ID : $WorkspaceId"
Write-Host ""

try {
    # -------------------------------------------------
    # Install & Import Power BI Module
    # -------------------------------------------------
    if (-not (Get-Module -ListAvailable -Name MicrosoftPowerBIMgmt)) {
        Install-Module MicrosoftPowerBIMgmt -Force -Scope CurrentUser -AllowClobber
    }
    Import-Module MicrosoftPowerBIMgmt

    # -------------------------------------------------
    # Authenticate using Service Principal
    # -------------------------------------------------
    Write-Host "Authenticating with Service Principal..."

    $securePassword = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential ($ClientId, $securePassword)

    Connect-PowerBIServiceAccount `
        -ServicePrincipal `
        -Credential $credential `
        -TenantId $TenantId `
        -ErrorAction Stop

    Write-Host "Authentication successful" -ForegroundColor Green

    # -------------------------------------------------
    # Verify Workspace
    # -------------------------------------------------
    $workspace = Get-PowerBIWorkspace -Id $WorkspaceId -ErrorAction Stop
    Write-Host "Workspace found: $($workspace.Name)" -ForegroundColor Green

    # -------------------------------------------------
    # Detect report existence
    # -------------------------------------------------
    $reportName = [System.IO.Path]::GetFileNameWithoutExtension($ReportPath)
    $existingReports = Get-PowerBIReport -WorkspaceId $WorkspaceId -ErrorAction SilentlyContinue
    $existingReport = $existingReports | Where-Object { $_.Name -eq $reportName }

    if ($existingReport) {
        Write-Host "Report exists → Overwriting report (dataset preserved)" -ForegroundColor Cyan
    }
    else {
        Write-Host "Report does not exist → First-time publish" -ForegroundColor Yellow
    }

    # -------------------------------------------------
    # Publish report (ALWAYS CreateOrOverwrite)
    # -------------------------------------------------
    $report = New-PowerBIReport `
        -Path $ReportPath `
        -WorkspaceId $WorkspaceId `
        -Name $reportName `
        -ConflictAction CreateOrOverwrite `
        -ErrorAction Stop

    Write-Host "Report published successfully" -ForegroundColor Green
    Write-Host "Report ID: $($report.Id)"

    # -------------------------------------------------
    # Get Dataset ID (reused automatically)
    # -------------------------------------------------
    $datasets = Get-PowerBIDataset -WorkspaceId $WorkspaceId
    $dataset = $datasets | Where-Object { $_.Name -eq $reportName } | Select-Object -First 1

    if ($dataset) {
        Write-Host "Dataset ID: $($dataset.Id)" -ForegroundColor Green
        Write-Host "##vso[task.setvariable variable=DatasetId]$($dataset.Id)"
    }
    else {
        Write-Warning "Dataset not found after publish"
    }

    # -------------------------------------------------
    # Set pipeline variables
    # -------------------------------------------------
    Write-Host "##vso[task.setvariable variable=ReportId]$($report.Id)"
    Write-Host "##vso[task.setvariable variable=ReportName]$reportName"

    exit 0
}
catch {
    Write-Error "Failed to publish report"
    Write-Error $_.Exception.Message
    exit 1
}
