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
    [string]$SharePointSiteUrl,

    [Parameter(Mandatory = $true)]
    [string]$FilePath
)

Write-Host "============================================"
Write-Host "Updating SharePoint Dataset Parameters"
Write-Host "============================================"
Write-Host "Workspace ID : $WorkspaceId"
Write-Host "Dataset ID   : $DatasetId"
Write-Host "Site URL     : $SharePointSiteUrl"
Write-Host "File Path    : $FilePath"
Write-Host ""

try {
    # Get token
    $tokenBody = @{
        grant_type    = "client_credentials"
        client_id     = $ClientId
        client_secret = $ClientSecret
        resource      = "https://analysis.windows.net/powerbi/api"
    }

    $tokenUrl = "https://login.microsoftonline.com/$TenantId/oauth2/token"
    $token = (Invoke-RestMethod -Method Post -Uri $tokenUrl -Body $tokenBody).access_token

    if (-not $token) { throw "Failed to get access token" }

    $headers = @{
        Authorization = "Bearer $token"
        "Content-Type" = "application/json"
    }

    # Validate parameters
    $paramsUrl = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/datasets/$DatasetId/parameters"
    $existing = (Invoke-RestMethod -Method Get -Uri $paramsUrl -Headers $headers).value.name

    if (-not ($existing -contains "SharePointSiteUrl")) {
        throw "Parameter 'SharePointSiteUrl' not found in dataset"
    }
    if (-not ($existing -contains "FilePath")) {
        throw "Parameter 'FilePath' not found in dataset"
    }

    Write-Host "Parameters validated successfully"

    # Update parameters
    $body = @{
        updateDetails = @(
            @{
                name = "SharePointSiteUrl"
                newValue = $SharePointSiteUrl
            },
            @{
                name = "FilePath"
                newValue = $FilePath
            }
        )
    } | ConvertTo-Json -Depth 5

    $updateUrl = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/datasets/$DatasetId/UpdateParameters"
    Invoke-RestMethod -Method Post -Uri $updateUrl -Headers $headers -Body $body

    Write-Host "Dataset parameters updated successfully" -ForegroundColor Green
    exit 0
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
 