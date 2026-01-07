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
    [string]$DatasetId,

    [Parameter(Mandatory = $true)]
    [string]$OneDriveSiteUrl,

    [Parameter(Mandatory = $true)]
    [string]$OneDriveFilePath
)

Write-Host "============================================"
Write-Host "Updating OneDrive Parameters"
Write-Host "============================================"
Write-Host "Workspace ID : $WorkspaceId"
Write-Host "Dataset ID   : $DatasetId"
Write-Host "Site URL     : $OneDriveSiteUrl"
Write-Host "File Path    : $OneDriveFilePath"
Write-Host ""

try {
    # -----------------------------------------
    # Get Power BI access token
    # -----------------------------------------
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
        throw "Failed to obtain Power BI access token"
    }

    $headers = @{
        Authorization = "Bearer $accessToken"
        "Content-Type" = "application/json"
    }

    Write-Host "Access token obtained" -ForegroundColor Green

    # -----------------------------------------
    # Validate parameters exist in dataset
    # -----------------------------------------
    $paramsUrl = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/datasets/$DatasetId/parameters"
    $existingParams = Invoke-RestMethod -Uri $paramsUrl -Headers $headers -Method Get

    $paramNames = $existingParams.value.name

    if (-not ($paramNames -contains "OneDriveSiteUrl")) {
        throw "Dataset parameter 'OneDriveSiteUrl' does not exist in PBIX"
    }

    if (-not ($paramNames -contains "OneDriveFilePath")) {
        throw "Dataset parameter 'OneDriveFilePath' does not exist in PBIX"
    }

    Write-Host "Required parameters found in dataset" -ForegroundColor Green

    # -----------------------------------------
    # Update parameters
    # -----------------------------------------
    $updateBody = @{
        updateDetails = @(
            @{
                name = "OneDriveSiteUrl"
                newValue = $OneDriveSiteUrl
            },
            @{
                name = "OneDriveFilePath"
                newValue = $OneDriveFilePath
            }
        )
    } | ConvertTo-Json -Depth 5

    Write-Host ""
    Write-Host "Updating dataset parameters..."
    Write-Host $updateBody

    $updateUrl = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/datasets/$DatasetId/UpdateParameters"
    Invoke-RestMethod -Uri $updateUrl -Headers $headers -Method Post -Body $updateBody

    Write-Host ""
    Write-Host "Parameters updated successfully" -ForegroundColor Green
    exit 0
}
catch {
    Write-Error "Failed to update dataset parameters"
    Write-Error $_.Exception.Message
    exit 1
}
