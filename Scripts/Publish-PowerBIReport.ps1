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
    # Install module if missing
    if (-not (Get-Module -ListAvailable -Name MicrosoftPowerBIMgmt)) {
        Install-Module MicrosoftPowerBIMgmt -Force -Scope CurrentUser -AllowClobber
    }
    Import-Module MicrosoftPowerBIMgmt
 
    # Authenticate
    Write-Host "Authenticating with Service Principal..."
    $securePassword = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential ($ClientId, $securePassword)
 
    Connect-PowerBIServiceAccount `
        -ServicePrincipal `
        -Credential $credential `
        -TenantId $TenantId `
        -ErrorAction Stop
 
    Write-Host "Authentication successful" -ForegroundColor Green
 
    # Validate workspace
    $workspace = Get-PowerBIWorkspace -Id $WorkspaceId -ErrorAction Stop
    Write-Host "Workspace found: $($workspace.Name)" -ForegroundColor Green
 
    # Publish (ALWAYS CreateOrOverwrite)
    $reportName = [System.IO.Path]::GetFileNameWithoutExtension($ReportPath)
 
    Write-Host "Publishing report using CreateOrOverwrite..."
 
    $report = New-PowerBIReport `
        -Path $ReportPath `
        -WorkspaceId $WorkspaceId `
        -Name $reportName `
        -ConflictAction CreateOrOverwrite `
        -ErrorAction Stop
 
    Write-Host "Report published successfully" -ForegroundColor Green
    Write-Host "Report ID: $($report.Id)"
 
    # Fetch dataset
    $dataset = Get-PowerBIDataset -WorkspaceId $WorkspaceId |
               Where-Object { $_.Name -eq $reportName } |
               Select-Object -First 1
 
    if ($dataset) {
        Write-Host "Dataset ID: $($dataset.Id)" -ForegroundColor Green
        Write-Host "##vso[task.setvariable variable=DatasetId]$($dataset.Id)"
    }
 
    Write-Host "##vso[task.setvariable variable=ReportId]$($report.Id)"
    Write-Host "##vso[task.setvariable variable=ReportName]$reportName"
 
    exit 0
}
catch {
    Write-Error "Publish failed"
    Write-Error $_.Exception.Message
    exit 1
}