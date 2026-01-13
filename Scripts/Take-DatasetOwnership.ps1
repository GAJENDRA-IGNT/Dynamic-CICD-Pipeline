param (
    [Parameter(Mandatory = $true)]
    [string]$ClientId,

    [Parameter(Mandatory = $true)]
    [string]$ClientSecret,

    [Parameter(Mandatory = $true)]
    [string]$TenantId,

    [Parameter(Mandatory = $true)]
    [string]$WorkspaceId,

    [Parameter(Mandatory = $true)]
    [string]$DatasetId
)

Write-Host "============================================"
Write-Host "Taking Dataset Ownership"
Write-Host "============================================"
Write-Host "Workspace ID : $WorkspaceId"
Write-Host "Dataset ID   : $DatasetId"
Write-Host ""

try {
    # Get Power BI Access Token
    $tokenBody = @{
        grant_type    = "client_credentials"
        client_id     = $ClientId
        client_secret = $ClientSecret
        resource      = "https://analysis.windows.net/powerbi/api"
    }

    $tokenUrl = "https://login.microsoftonline.com/$TenantId/oauth2/token"
    $tokenResponse = Invoke-RestMethod -Method Post -Uri $tokenUrl -Body $tokenBody
    $accessToken = $tokenResponse.access_token

    if (-not $accessToken) {
        throw "Failed to obtain access token"
    }

    $headers = @{
        Authorization  = "Bearer $accessToken"
        "Content-Type" = "application/json"
    }

    Write-Host "Access token obtained" -ForegroundColor Green

    # Check current dataset owner
    $datasetUrl = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/datasets/$DatasetId"
    
    try {
        $datasetInfo = Invoke-RestMethod -Method Get -Uri $datasetUrl -Headers $headers
        Write-Host "Dataset Name: $($datasetInfo.name)"
        Write-Host "Current Owner: $($datasetInfo.configuredBy)"
    }
    catch {
        Write-Warning "Could not get current owner info"
    }

    # Take Dataset Ownership
    $takeoverUrl = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/datasets/$DatasetId/Default.TakeOver"

    Write-Host ""
    Write-Host "Taking ownership of dataset..."

    try {
        Invoke-RestMethod -Method Post -Uri $takeoverUrl -Headers $headers
        
        Write-Host ""
        Write-Host "================================================" -ForegroundColor Green
        Write-Host "Dataset ownership successfully taken!" -ForegroundColor Green
        Write-Host "================================================" -ForegroundColor Green
    }
    catch {
        $errorMessage = $_.Exception.Message
        
        # Check if already owner (not an error)
        if ($errorMessage -match "already the owner" -or $_.Exception.Response.StatusCode -eq 400) {
            Write-Host ""
            Write-Host "Service Principal is already the owner" -ForegroundColor Yellow
            Write-Host "Continuing..." -ForegroundColor Yellow
        }
        else {
            throw $_
        }
    }

    exit 0
}
catch {
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Red
    Write-Error "Failed to take dataset ownership"
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