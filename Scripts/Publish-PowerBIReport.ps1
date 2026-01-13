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
        Write-Host "Installing MicrosoftPowerBIMgmt module..."
        Install-Module MicrosoftPowerBIMgmt -Force -Scope CurrentUser -AllowClobber
    }
    Import-Module MicrosoftPowerBIMgmt

    # Authenticate with Service Principal
    Write-Host "Authenticating with Service Principal..."
    $securePassword = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential ($ClientId, $securePassword)

    Connect-PowerBIServiceAccount `
        -ServicePrincipal `
        -Credential $credential `
        -TenantId $TenantId `
        -ErrorAction Stop

    Write-Host "Authentication successful" -ForegroundColor Green

    # Validate workspace exists
    $workspace = Get-PowerBIWorkspace -Id $WorkspaceId -ErrorAction Stop
    Write-Host "Workspace found: $($workspace.Name)" -ForegroundColor Green

    # Get report name
    $reportName = [System.IO.Path]::GetFileNameWithoutExtension($ReportPath)

    # Check if dataset already exists (to preserve settings)
    $existingDataset = Get-PowerBIDataset -WorkspaceId $WorkspaceId | 
                       Where-Object { $_.Name -eq $reportName } | 
                       Select-Object -First 1

    if ($existingDataset) {
        Write-Host "Existing dataset found: $($existingDataset.Id)" -ForegroundColor Yellow
        Write-Host "Will overwrite and preserve gateway bindings..." -ForegroundColor Yellow
    }

    # Publish report with CreateOrOverwrite (preserves dataset ID)
    Write-Host ""
    Write-Host "Publishing report using CreateOrOverwrite..."

    $report = New-PowerBIReport `
        -Path $ReportPath `
        -WorkspaceId $WorkspaceId `
        -Name $reportName `
        -ConflictAction CreateOrOverwrite `
        -ErrorAction Stop

    Write-Host ""
    Write-Host "================================================" -ForegroundColor Green
    Write-Host "Report published successfully!" -ForegroundColor Green
    Write-Host "================================================" -ForegroundColor Green
    Write-Host "Report ID   : $($report.Id)"
    Write-Host "Report Name : $reportName"

    # Wait for dataset to be available
    Start-Sleep -Seconds 5

    # Get dataset ID
    $dataset = Get-PowerBIDataset -WorkspaceId $WorkspaceId |
               Where-Object { $_.Name -eq $reportName } |
               Select-Object -First 1

    if ($dataset) {
        Write-Host "Dataset ID  : $($dataset.Id)" -ForegroundColor Green
        
        # Set pipeline variables for subsequent steps
        Write-Host "##vso[task.setvariable variable=DatasetId]$($dataset.Id)"
        Write-Host "##vso[task.setvariable variable=ReportId]$($report.Id)"
        Write-Host "##vso[task.setvariable variable=ReportName]$reportName"
    }
    else {
        Write-Warning "Could not find dataset after publish"
    }

    Write-Host ""
    exit 0
}
catch {
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Red
    Write-Error "Publish failed!"
    Write-Host "================================================" -ForegroundColor Red
    Write-Error $_.Exception.Message
    
    if ($_.Exception.Response) {
        try {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $responseBody = $reader.ReadToEnd()
            Write-Error "Response: $responseBody"
        }
        catch { }
    }
    
    exit 1
}