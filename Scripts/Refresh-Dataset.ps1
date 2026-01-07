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

    [Parameter(Mandatory = $false)]
    [string]$Environment = "DEV"
)

Write-Host "============================================"
Write-Host "Refreshing Power BI Dataset"
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
    
    Write-Host "Access token obtained" -ForegroundColor Green
    
    $headers = @{
        "Authorization" = "Bearer $accessToken"
        "Content-Type"  = "application/json"
    }
    
    # Check if dataset exists
    Write-Host "Verifying dataset exists..."
    $datasetUrl = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/datasets/$DatasetId"
    
    try {
        $datasetInfo = Invoke-RestMethod -Uri $datasetUrl -Headers $headers -Method Get
        Write-Host "Dataset found: $($datasetInfo.name)" -ForegroundColor Green
    }
    catch {
        Write-Warning "Could not verify dataset: $($_.Exception.Message)"
    }
    
    # Trigger dataset refresh
    $refreshUrl = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/datasets/$DatasetId/refreshes"
    
    Write-Host ""
    Write-Host "Triggering dataset refresh..."
    $refreshBody = @{
        notifyOption = "NoNotification"
    } | ConvertTo-Json
    
    Invoke-RestMethod -Uri $refreshUrl -Headers $headers -Method Post -Body $refreshBody
    
    Write-Host "Dataset refresh initiated successfully" -ForegroundColor Green
    
    # Poll for refresh status
    Write-Host ""
    Write-Host "Monitoring refresh status..."
    Write-Host "(This may take a few minutes)"
    
    $maxAttempts = 30
    $attempt = 0
    $refreshCompleted = $false
    $refreshFailed = $false
    
    do {
        Start-Sleep -Seconds 10
        $attempt++
        
        try {
            $statusUrl = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/datasets/$DatasetId/refreshes?`$top=1"
            $status = Invoke-RestMethod -Uri $statusUrl -Headers $headers -Method Get
            
            $latestRefresh = $status.value[0]
            $currentStatus = $latestRefresh.status
            
            Write-Host "  Attempt $attempt/$maxAttempts - Status: $currentStatus"
            
            if ($currentStatus -eq "Completed") {
                Write-Host ""
                Write-Host "==================================================" -ForegroundColor Green
                Write-Host "Dataset refresh completed successfully!" -ForegroundColor Green
                Write-Host "==================================================" -ForegroundColor Green
                $refreshCompleted = $true
                break
            }
            elseif ($currentStatus -eq "Failed") {
                Write-Host ""
                Write-Host "==================================================" -ForegroundColor Yellow
                Write-Warning "Dataset refresh failed"
                Write-Host "==================================================" -ForegroundColor Yellow
                
                # Try to get error details
                if ($latestRefresh.serviceExceptionJson) {
                    Write-Warning "Error details: $($latestRefresh.serviceExceptionJson)"
                }
                
                # Get refresh history for more details
                try {
                    $historyUrl = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/datasets/$DatasetId/refreshes?`$top=1"
                    $history = Invoke-RestMethod -Uri $historyUrl -Headers $headers -Method Get
                    
                    if ($history.value -and $history.value[0]) {
                        $lastRefresh = $history.value[0]
                        Write-Host ""
                        Write-Host "Last refresh details:"
                        Write-Host "  Start Time: $($lastRefresh.startTime)"
                        Write-Host "  End Time: $($lastRefresh.endTime)"
                        Write-Host "  Status: $($lastRefresh.status)"
                        Write-Host "  Refresh Type: $($lastRefresh.refreshType)"
                        
                        if ($lastRefresh.serviceExceptionJson) {
                            $errorJson = $lastRefresh.serviceExceptionJson | ConvertFrom-Json
                            Write-Warning "Error message: $($errorJson.errorDescription)"
                        }
                    }
                }
                catch {
                    Write-Warning "Could not retrieve detailed error info"
                }
                
                $refreshFailed = $true
                break
            }
        }
        catch {
            Write-Warning "Error checking refresh status: $($_.Exception.Message)"
        }
        
    } while ($attempt -lt $maxAttempts -and $currentStatus -in @("Unknown", "InProgress"))
    
    if ($attempt -ge $maxAttempts -and -not $refreshCompleted -and -not $refreshFailed) {
        Write-Host ""
        Write-Warning "Refresh status check timed out after $($maxAttempts * 10) seconds"
        Write-Warning "The refresh may still be in progress"
        Write-Warning "Check Power BI Service for current refresh status"
    }
    
    # Common reasons for refresh failures
    Write-Host ""
    Write-Host "Common reasons for refresh failures:" -ForegroundColor Cyan
    Write-Host "  1. Data source credentials not configured in Power BI Service"
    Write-Host "  2. OneDrive file permissions not granted to Service Principal"
    Write-Host "  3. Parameter values pointing to inaccessible file"
    Write-Host "  4. Dataset has no data source connection configured"
    Write-Host ""
    Write-Host "To fix refresh issues:"
    Write-Host "  - Go to Power BI Service > Workspace > Dataset Settings"
    Write-Host "  - Configure data source credentials"
    Write-Host "  - Test manual refresh in Power BI Service"
    
    # Always exit with success since continueOnError handles this
    Write-Host ""
    Write-Host "Refresh step completed (check status above)" -ForegroundColor Cyan
    exit 0
}
catch {
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Yellow
    Write-Warning "Could not trigger dataset refresh"
    Write-Host "==================================================" -ForegroundColor Yellow
    Write-Warning "Error: $($_.Exception.Message)"
    
    if ($_.Exception.Response) {
        try {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $responseBody = $reader.ReadToEnd()
            Write-Warning "Response: $responseBody"
        }
        catch {
            Write-Warning "Could not read error response"
        }
    }
    
    Write-Host ""
    Write-Host "Possible reasons:" -ForegroundColor Cyan
    Write-Host "  - Dataset doesn't support refresh (import model required)"
    Write-Host "  - Service Principal lacks permissions"
    Write-Host "  - Dataset credentials not configured"
    Write-Host ""
    Write-Host "Note: This step is optional - reports are still deployed successfully" -ForegroundColor Green
    
    # Exit with success - let continueOnError handle this gracefully
    exit 0
}