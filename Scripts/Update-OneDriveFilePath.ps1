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
    [string]$DatasetId,

    [Parameter(Mandatory = $true)]
    [string]$OneDriveSiteUrl,

    [Parameter(Mandatory = $true)]
    [string]$OneDriveFilePath,

    [Parameter(Mandatory = $false)]
    [string]$Environment = "DEV"
)

Write-Host "============================================"
Write-Host "Updating OneDrive Parameters ($Environment)"
Write-Host "============================================"
Write-Host "Workspace ID        : $WorkspaceId"
Write-Host "Dataset ID          : $DatasetId"
Write-Host "OneDriveSiteUrl     : $OneDriveSiteUrl"
Write-Host "OneDriveFilePath    : $OneDriveFilePath"
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

    Write-Host "✓ Access token obtained" -ForegroundColor Green

    $headers = @{
        "Authorization" = "Bearer $accessToken"
        "Content-Type"  = "application/json"
    }

    # -----------------------------------------
    # Read Existing Parameters
    # -----------------------------------------
    $paramsUrl = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/datasets/$DatasetId/parameters"

    Write-Host ""
    Write-Host "Reading existing dataset parameters..."

    try {
        $currentParams = Invoke-RestMethod -Uri $paramsUrl -Headers $headers -Method Get

        foreach ($p in $currentParams.value) {
            Write-Host "  - $($p.name): $($p.currentValue)"
        }
    }
    catch {
        Write-Warning "Could not read existing parameters (dataset may not have parameters yet)"
    }

    # -----------------------------------------
    # Build Parameter Update Body
    # -----------------------------------------
    $updateBody = @{
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
    } | ConvertTo-Json -Depth 10

    Write-Host ""
    Write-Host "Updating dataset parameters..."
    Write-Host $updateBody

    # -----------------------------------------
    # Update Parameters
    # -----------------------------------------
    $updateUrl = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/datasets/$DatasetId/UpdateParameters"

    Invoke-RestMethod `
        -Uri $updateUrl `
        -Headers $headers `
        -Method Post `
        -Body $updateBody `
        -ErrorAction Stop

    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Green
    Write-Host "Parameters updated successfully ($Environment)" -ForegroundColor Green
    Write-Host "==================================================" -ForegroundColor Green

    # -----------------------------------------
    # Verify Update
    # -----------------------------------------
    Write-Host ""
    Write-Host "Verifying updated parameters..."
    Start-Sleep -Seconds 2

    $verifyParams = Invoke-RestMethod -Uri $paramsUrl -Headers $headers -Method Get

    foreach ($p in $verifyParams.value) {
        Write-Host "✓ $($p.name): $($p.currentValue)" -ForegroundColor Green
    }

    exit 0
}
catch {
    Write-Host ""
    Write-Error "❌ Failed to update dataset parameters"
    Write-Error $_.Exception.Message

    if ($_.Exception.Response) {
        try {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $responseBody = $reader.ReadToEnd()
            Write-Error "Response: $responseBody"
        }
        catch {
            Write-Warning "Could not read error response"
        }
    }

    exit 1
}
