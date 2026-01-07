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
    # -----------------------------
    # Get Access Token
    # -----------------------------
    $tokenBody = @{
        grant_type    = "client_credentials"
        client_id     = $ClientId
        client_secret = $ClientSecret
        resource      = "https://analysis.windows.net/powerbi/api"
    }

    $tokenUrl = "https://login.microsoftonline.com/$TenantId/oauth2/token"
    $tokenResponse = Invoke-RestMethod -Method Post -Uri $tokenUrl -Body $tokenBody
    $accessToken = $tokenResponse.access_token

    $headers = @{
        Authorization = "Bearer $accessToken"
        "Content-Type" = "application/json"
    }

    Write-Host "Access token obtained"

    # -----------------------------
    # Build request body
    # -----------------------------
    $body = @{
        updateDetails = @(
            @{
                name     = "OneDriveSiteUrl"
                newValue = $OneDriveSiteUrl
            },
            @{
                name     = "OneDriveFilePath"
                newValue = $OneDriveFilePath
            }
        )
    } | ConvertTo-Json -Depth 5

    Write-Host ""
    Write-Host "Updating dataset parameters..."
    Write-Host $body

    # -----------------------------
    # Update parameters
    # -----------------------------
    $updateUrl = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/datasets/$DatasetId/Default.UpdateParameters"

    Invoke-RestMethod `
        -Method Post `
        -Uri $updateUrl `
        -Headers $headers `
        -Body $body

    Write-Host ""
    Write-Host "OneDrive parameters updated successfully" -ForegroundColor Green
    exit 0
}
catch {
    Write-Error "Failed to update dataset parameters"
    Write-Error $_.Exception.Message
    exit 1
}
