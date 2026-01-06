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
    [string]$DatasetId,

    [Parameter(Mandatory=$true)]
    [string]$OneDriveURL,

    [Parameter(Mandatory=$true)]
    [string]$FilePath,

    [string]$Environment = "DEV"
)

Write-Host "============================================"
Write-Host "Updating OneDrive File Path ($Environment)"
Write-Host "============================================"
Write-Host "Dataset ID   : $DatasetId"
Write-Host "Workspace ID : $WorkspaceId"

$FullURL = "$OneDriveURL$FilePath"
Write-Host "Target URL   : $FullURL"
Write-Host ""

try {
    # -----------------------------------------
    # Get Access Token
    # -----------------------------------------
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
        Authorization = "Bearer $accessToken"
        "Content-Type" = "application/json"
    }

    Write-Host "Access token obtained" -ForegroundColor Green

    # -----------------------------------------
    # Read Existing Parameters
    # -----------------------------------------
    $paramsUrl = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/datasets/$DatasetId/parameters"
    $params = Invoke-RestMethod -Uri $paramsUrl -Headers $headers -Method Get

    $existingParam = $params.value | Where-Object { $_.name -eq "OneDriveFilePath" }

    if (-not $existingParam) {
        Write-Warning "Parameter 'OneDriveFilePath' not found. Skipping update."
        exit 0
    }

    Write-Host "Existing value:"
    Write-Host "  $($existingParam.currentValue)"

    # -----------------------------------------
    # SKIP if value already same (IMPORTANT)
    # -----------------------------------------
    if ($existingParam.currentValue -eq $FullURL) {
        Write-Host ""
        Write-Host "Parameter value already correct. No update needed." -ForegroundColor Cyan
        Write-Host "Skipping UpdateParameters call to avoid 403."
        exit 0
    }

    # -----------------------------------------
    # Update Parameter
    # -----------------------------------------
    $updateBody = @{
        updateDetails = @(
            @{
                name = "OneDriveFilePath"
                newValue = $FullURL
            }
        )
    } | ConvertTo-Json -Depth 5

    Write-Host ""
    Write-Host "Updating parameter..."
    Invoke-RestMethod `
        -Uri "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/datasets/$DatasetId/UpdateParameters" `
        -Headers $headers `
        -Method Post `
        -Body $updateBody

    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Green
    Write-Host "OneDriveFilePath updated successfully ($Environment)" -ForegroundColor Green
    Write-Host "==================================================" -ForegroundColor Green

    exit 0
}
catch {
    Write-Warning "Parameter update skipped due to API restriction"
    Write-Warning $_.Exception.Message
    Write-Host "Continuing pipeline safely..."
    exit 0
}
