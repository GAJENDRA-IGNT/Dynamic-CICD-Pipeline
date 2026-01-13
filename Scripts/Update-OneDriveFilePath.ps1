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
Write-Host "Updating SharePoint/OneDrive Parameters"
Write-Host "============================================"
Write-Host "Workspace ID : $WorkspaceId"
Write-Host "Dataset ID   : $DatasetId"
Write-Host "Site URL     : $SharePointSiteUrl"
Write-Host "File Path    : $FilePath"
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

    # Get existing parameters
    Write-Host ""
    Write-Host "Retrieving existing parameters..."
    
    $paramsUrl = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/datasets/$DatasetId/parameters"
    $existingParams = Invoke-RestMethod -Method Get -Uri $paramsUrl -Headers $headers
    
    Write-Host "Found parameters:"
    foreach ($param in $existingParams.value) {
        Write-Host "  - $($param.name): $($param.currentValue)"
    }

    # Validate required parameters exist
    $paramNames = $existingParams.value.name

    if (-not ($paramNames -contains "SharePointSiteUrl")) {
        throw "Parameter 'SharePointSiteUrl' not found in dataset. Please ensure your Power BI report has this parameter defined."
    }

    if (-not ($paramNames -contains "FilePath")) {
        throw "Parameter 'FilePath' not found in dataset. Please ensure your Power BI report has this parameter defined."
    }

    Write-Host ""
    Write-Host "Required parameters validated successfully" -ForegroundColor Green

    # Build update request
    $updateDetails = @(
        @{
            name     = "SharePointSiteUrl"
            newValue = $SharePointSiteUrl
        },
        @{
            name     = "FilePath"
            newValue = $FilePath
        }
    )

    $body = @{
        updateDetails = $updateDetails
    } | ConvertTo-Json -Depth 5

    Write-Host ""
    Write-Host "Updating parameters..."
    Write-Host "  SharePointSiteUrl -> $SharePointSiteUrl"
    Write-Host "  FilePath -> $FilePath"

    # Update parameters
    $updateUrl = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/datasets/$DatasetId/Default.UpdateParameters"
    
    Invoke-RestMethod -Method Post -Uri $updateUrl -Headers $headers -Body $body

    Write-Host ""
    Write-Host "================================================" -ForegroundColor Green
    Write-Host "Parameters updated successfully!" -ForegroundColor Green
    Write-Host "================================================" -ForegroundColor Green

    # Verify update
    Write-Host ""
    Write-Host "Verifying parameter update..."
    
    $verifyParams = Invoke-RestMethod -Method Get -Uri $paramsUrl -Headers $headers
    
    foreach ($param in $verifyParams.value) {
        if ($param.name -eq "SharePointSiteUrl") {
            Write-Host "  SharePointSiteUrl = $($param.currentValue)" -ForegroundColor Green
        }
        if ($param.name -eq "FilePath") {
            Write-Host "  FilePath = $($param.currentValue)" -ForegroundColor Green
        }
    }

    exit 0
}
catch {
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Red
    Write-Error "Failed to update parameters"
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

    Write-Host ""
    Write-Host "Troubleshooting tips:" -ForegroundColor Cyan
    Write-Host "  1. Ensure parameters exist in Power BI Desktop:"
    Write-Host "     - Transform Data -> Manage Parameters"
    Write-Host "     - Create 'SharePointSiteUrl' (Text)"
    Write-Host "     - Create 'FilePath' (Text)"
    Write-Host "  2. Verify dataset ownership has been taken"
    Write-Host "  3. Check parameter names match exactly (case-sensitive)"
    Write-Host ""

    exit 1
}