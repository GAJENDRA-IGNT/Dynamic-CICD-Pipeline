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
    # --------------------------------------------------
    # Get Power BI Access Token (Service Principal)
    # --------------------------------------------------
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
        Authorization = "Bearer $accessToken"
        "Content-Type" = "application/json"
    }

    Write-Host "Access token obtained"

    # --------------------------------------------------
    # Take Dataset Ownership
    # --------------------------------------------------
    $takeoverUrl = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/datasets/$DatasetId/Default.TakeOver"

    Write-Host ""
    Write-Host "Taking ownership of dataset..."

    Invoke-RestMethod `
        -Method Post `
        -Uri $takeoverUrl `
        -Headers $headers

    Write-Host ""
    Write-Host "Dataset ownership successfully taken" -ForegroundColor Green
    exit 0
}
catch {
    Write-Error "Failed to take dataset ownership"
    Write-Error $_.Exception.Message
    exit 1
}
 