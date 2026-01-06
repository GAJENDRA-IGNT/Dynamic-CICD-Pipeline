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
    
    [Parameter(Mandatory=$false)]
    [string]$Environment = "DEV"
)

Write-Host "============================================"
Write-Host "Updating OneDrive File Path ($Environment)"
Write-Host "============================================"
Write-Host "Dataset ID: $DatasetId"
Write-Host "Workspace ID: $WorkspaceId"
Write-Host "OneDrive URL: $OneDriveURL"
Write-Host "File Path: $FilePath"

# Construct full URL
$fullURL = $OneDriveURL + $FilePath
Write-Host "Full URL: $fullURL"
Write-Host ""

try {
    # Get access token
    $tokenBody = @{
        grant_type    = "client_credentials"
        client_id     = $ClientId
        client_secret = $ClientSecret
        resource      = "https://analysis.windows.net/powerbi/api"
    }
    
    $tokenUrl = "https://login.microsoftonline.com/$TenantId/oauth2/token"
    $tokenResponse = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $tokenBody
    $accessToken = $tokenResponse.access_token
    
    Write-Host "Access token obtained" -ForegroundColor Green
    
    $headers = @{
        "Authorization" = "Bearer $accessToken"
        "Content-Type"  = "application/json"
    }
    
    # Get current parameters
    $getParamsUrl = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/datasets/$DatasetId/parameters"
    
    Write-Host "Getting current parameters..."
    try {
        $currentParams = Invoke-RestMethod -Uri $getParamsUrl -Headers $headers -Method Get
        
        Write-Host "Current parameters:"
        foreach ($param in $currentParams.value) {
            Write-Host "  - $($param.name): $($param.currentValue)"
        }
    }
    catch {
        Write-Warning "Could not get current parameters: $($_.Exception.Message)"
        Write-Host "Dataset may not have parameters configured yet"
    }
    
    # Build update body
    $updateDetails = @(
        @{
            name = "OneDriveFilePath"
            newValue = $fullURL
        }
    )
    
    Write-Host ""
    Write-Host "Will update parameter:"
    Write-Host "  OneDriveFilePath -> $fullURL" -ForegroundColor Cyan
    
    $updateBody = @{
        updateDetails = $updateDetails
    } | ConvertTo-Json -Depth 10
    
    Write-Host ""
    Write-Host "Request body:"
    Write-Host $updateBody
    
    # Update parameters
    $updateUrl = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/datasets/$DatasetId/UpdateParameters"
    
    Write-Host ""
    Write-Host "Updating parameters..."
    Invoke-RestMethod -Uri $updateUrl -Headers $headers -Method Post -Body $updateBody
    
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Green
    Write-Host "Parameters updated successfully for $Environment!" -ForegroundColor Green
    Write-Host "==================================================" -ForegroundColor Green
    
    # Verify update
    Write-Host ""
    Write-Host "Verifying updated parameters..."
    Start-Sleep -Seconds 2
    $verifyParams = Invoke-RestMethod -Uri $getParamsUrl -Headers $headers -Method Get
    
    Write-Host "Verified parameters:"
    foreach ($param in $verifyParams.value) {
        Write-Host "  $($param.name): $($param.currentValue)" -ForegroundColor Green
    }
    
    exit 0
}
catch {
    Write-Error "Failed to update parameters: $_"
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