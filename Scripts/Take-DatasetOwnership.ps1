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
    [string]$DatasetId
)

Write-Host "============================================"
Write-Host "Taking Dataset Ownership"
Write-Host "============================================"
Write-Host "Dataset ID: $DatasetId"
Write-Host "Workspace ID: $WorkspaceId"
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
    
    Write-Host "✓ Access token obtained" -ForegroundColor Green
    
    $headers = @{
        "Authorization" = "Bearer $accessToken"
        "Content-Type"  = "application/json"
    }
    
    # Take ownership
    $takeOwnershipUrl = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/datasets/$DatasetId/Default.TakeOver"
    
    Write-Host "Taking ownership of dataset..."
    Invoke-RestMethod -Uri $takeOwnershipUrl -Headers $headers -Method Post
    
    Write-Host "✓ Successfully took ownership of dataset" -ForegroundColor Green
    
    return @{
        Success = $true
    }
}
catch {
    Write-Warning "Could not take ownership: $_"
    Write-Warning "This may be normal if Service Principal already owns the dataset"
    # Don't fail - this is optional
    return @{
        Success = $false
        Error = $_.Exception.Message
    }
}