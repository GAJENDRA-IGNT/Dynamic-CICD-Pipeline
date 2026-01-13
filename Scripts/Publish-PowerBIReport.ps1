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
    [string]$ReportPath,

    [switch]$FirstDeployment
)

Write-Host "============================================"
Write-Host "Publishing Power BI Report"
Write-Host "============================================"
Write-Host "Report Path      : $ReportPath"
Write-Host "Workspace ID     : $WorkspaceId"
Write-Host "First Deployment : $FirstDeployment"
Write-Host ""

try {
    # -----------------------------------------
    # Install & Import Power BI Module
    # -----------------------------------------
    if (-not (Get-Module -ListAvailable -Name MicrosoftPowerBIMgmt)) {
        Write-Host "Installing MicrosoftPowerBIMgmt module..."
        Install-Module -Name MicrosoftPowerBIMgmt -Force -Scope CurrentUser -AllowClobber
    }
    Import-Module MicrosoftPowerBIMgmt

    # -----------------------------------------
    # Authenticate using Service Principal
    # -----------------------------------------
    Write-Host "Authenticating with Service Principal..."
    $securePassword = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential ($ClientId, $securePassword)

    Connect-PowerBIServiceAccount `
        -ServicePrincipal `
        -Credential $credential `
        -TenantId $TenantId `
        -ErrorAction Stop

    Write-Host "Authentication successful" -ForegroundColor Green

    # -----------------------------------------
    # Verify Workspace
    # -----------------------------------------
    Write-Host "Verifying workspace access..."
    $workspace = Get-PowerBIWorkspace -Id $WorkspaceId -ErrorAction Stop
    Write-Host "Workspace found: $($workspace.Name)" -ForegroundColor Green

    # -----------------------------------------
    # Publish Report
    # -----------------------------------------
    $reportName = [System.IO.Path]::GetFileNameWithoutExtension($ReportPath)

    if ($FirstDeployment) {
        Write-Host "FIRST DEPLOYMENT: Creating dataset & report" -ForegroundColor Yellow
        $conflictAction = "CreateOrOverwrite"
    }
    else {
        Write-Host "UPDATE DEPLOYMENT: Preserving dataset" -ForegroundColor Green
        $conflictAction = "Overwrite"
    }

    Write-Host "Publishing report with ConflictAction = $conflictAction"

    $report = New-PowerBIReport `
        -Path $ReportPath `
        -WorkspaceId $WorkspaceId `
        -Name $reportName `
        -ConflictAction $conflictAction `
        -ErrorAction Stop

    Write-Host "Successfully published: $reportName" -ForegroundColor Green
    Write-Host "Report ID: $($report.Id)"

    # -----------------------------------------
    # Get DatasetId via REST API
    # -----------------------------------------
    Write-Host ""
    Write-Host "Retrieving Dataset ID..."

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
        Write-Warning "DatasetId not found via report endpoint. Searching datasets..."
        $datasetsUrl = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/datasets"
        $datasets = Invoke-RestMethod -Uri $datasetsUrl -Headers $headers -Method Get

        $matchingDataset = $datasets.value | Where-Object { $_.name -eq $reportName } | Select-Object -First 1

        if ($matchingDataset) {
            $datasetId = $matchingDataset.id
            Write-Host "Dataset found: $datasetId" -ForegroundColor Green
        }
        else {
            Write-Warning "No associated dataset found"
            $datasetId = ""
        }
    }
    else {
        Write-Host "Dataset ID: $datasetId" -ForegroundColor Green
    }

    # -----------------------------------------
    # Set Pipeline Variables
    # -----------------------------------------
    Write-Host ""
    Write-Host "Setting pipeline variables..."

    Write-Host "##vso[task.setvariable variable=ReportId]$($report.Id)"
    Write-Host "##vso[task.setvariable variable=DatasetId]$datasetId"
    Write-Host "##vso[task.setvariable variable=ReportName]$reportName"

    Write-Host ""
    Write-Host "Pipeline variables set successfully:"
    Write-Host "  ReportId   : $($report.Id)"
    Write-Host "  DatasetId  : $datasetId"
    Write-Host "  ReportName : $reportName"

    exit 0
}
catch {
    Write-Error "Failed to publish report"
    Write-Error $_.Exception.Message
    exit 1
}
