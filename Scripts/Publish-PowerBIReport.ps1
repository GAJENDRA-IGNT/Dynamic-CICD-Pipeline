param(
    [Parameter(Mandatory=$true)]
    [string]$ClientId,
    
    [Parameter(Mandatory=$true)]
    [string]$ClientSecret,
    
    [Parameter(Mandatory=$true)]
    [string]$TenantId,
    
    [Parameter(Mandatory=$true)]
    [string]$WorkspaceId,
    
    [Parameter(Mandatory=$true)]
    [string]$ReportPath
)

Write-Host "============================================"
Write-Host "Publishing Power BI Report"
Write-Host "============================================"
Write-Host "Report: $ReportPath"
Write-Host "Workspace ID: $WorkspaceId"
Write-Host ""

try {
    # Install and import module
    if (-not (Get-Module -ListAvailable -Name MicrosoftPowerBIMgmt)) {
        Write-Host "Installing MicrosoftPowerBIMgmt module..."
        Install-Module -Name MicrosoftPowerBIMgmt -Force -Scope CurrentUser -AllowClobber
    }
    Import-Module MicrosoftPowerBIMgmt

    # Authenticate
    Write-Host "Authenticating with Service Principal..."
    $securePassword = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential ($ClientId, $securePassword)
    Connect-PowerBIServiceAccount -ServicePrincipal -Credential $credential -TenantId $TenantId -ErrorAction Stop
    
    Write-Host "Authentication successful" -ForegroundColor Green
    
    # Verify workspace access
    Write-Host "Verifying workspace access..."
    $workspace = Get-PowerBIWorkspace -Id $WorkspaceId -ErrorAction Stop
    Write-Host "Workspace found: $($workspace.Name)" -ForegroundColor Green
    
    # Publish report
    Write-Host "Publishing report..."
    $reportName = [System.IO.Path]::GetFileNameWithoutExtension($ReportPath)
    
    $report = New-PowerBIReport -Path $ReportPath -WorkspaceId $WorkspaceId -Name $reportName -ConflictAction CreateOrOverwrite -ErrorAction Stop
    
    Write-Host "Successfully published: $reportName" -ForegroundColor Green
    Write-Host "  Report ID: $($report.Id)"
    
    # Get DatasetId using REST API
    Write-Host ""
    Write-Host "Getting Dataset ID via REST API..."
    
    $tokenBody = @{
        grant_type    = "client_credentials"
        client_id     = $ClientId
        client_secret = $ClientSecret
        resource      = "https://analysis.windows.net/powerbi/api"
    }
    
    $tokenUrl = "https://login.microsoftonline.com/$TenantId/oauth2/token"
    $tokenResponse = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $tokenBody
    $accessToken = $tokenResponse.access_token
    
    $headers = @{
        "Authorization" = "Bearer $accessToken"
        "Content-Type"  = "application/json"
    }
    
    $reportUrl = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/reports/$($report.Id)"
    $reportDetails = Invoke-RestMethod -Uri $reportUrl -Headers $headers -Method Get
    
    $datasetId = $reportDetails.datasetId
    
    if ([string]::IsNullOrEmpty($datasetId)) {
        Write-Warning "No DatasetId found in report object"
        Write-Host "Searching for dataset by report name..."
        
        $datasetsUrl = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/datasets"
        $datasets = Invoke-RestMethod -Uri $datasetsUrl -Headers $headers -Method Get
        
        $matchingDataset = $datasets.value | Where-Object { $_.name -eq $reportName } | Select-Object -First 1
        
        if ($matchingDataset) {
            $datasetId = $matchingDataset.id
            Write-Host "Found matching dataset: $datasetId" -ForegroundColor Green
        } else {
            Write-Warning "Could not find associated dataset"
            Write-Warning "This report may not have an embedded dataset"
            $datasetId = ""
        }
    } else {
        Write-Host "Dataset ID: $datasetId" -ForegroundColor Green
    }
    
    # Output for pipeline
    Write-Host ""
    Write-Host "Setting pipeline variables..."
    Write-Host "##vso[task.setvariable variable=ReportId]$($report.Id)"
    Write-Host "##vso[task.setvariable variable=DatasetId]$datasetId"
    Write-Host "##vso[task.setvariable variable=ReportName]$reportName"
    
    Write-Host ""
    Write-Host "Pipeline variables set:"
    Write-Host "  ReportId: $($report.Id)"
    Write-Host "  DatasetId: $datasetId"
    Write-Host "  ReportName: $reportName"
    
    exit 0
}
catch {
    Write-Error "Failed to publish report: $_"
    Write-Error $_.Exception.Message
    exit 1
}