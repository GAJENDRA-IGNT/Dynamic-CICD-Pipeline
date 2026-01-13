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
    [int]$TimeoutMinutes = 10
)

Write-Host "============================================"
Write-Host "Refreshing Power BI Dataset"
Write-Host "============================================"
Write-Host "Dataset ID   : $DatasetId"
Write-Host "Workspace ID : $WorkspaceId"
Write-Host "Timeout      : $TimeoutMinutes minutes"
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
    $tokenResponse = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $tokenBody
    $accessToken = $tokenResponse.access_token

    if (-not $accessToken) {
        throw "Failed to obtain access token"
    }

    $headers = @{
        "Authorization" = "Bearer $accessToken"
        "Content-Type"  = "application/json"
    }

    Write-Host "Access token obtained" -ForegroundColor Green

    # Verify dataset exists
    Write-Host ""
    Write-Host "Verifying dataset..."
    
    $datasetUrl = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/datasets/$DatasetId"

    try {
        $datasetInfo = Invoke-RestMethod -Uri $datasetUrl -Headers $headers -Method Get
        Write-Host "Dataset found: $($datasetInfo.name)" -ForegroundColor Green
        Write-Host "Configured by: $($datasetInfo.configuredBy)"
        Write-Host "Is Refreshable: $($datasetInfo.isRefreshable)"
        
        if (-not $datasetInfo.isRefreshable) {
            Write-Warning "Dataset is not refreshable (may be DirectQuery or Live Connection)"
            Write-Host "Skipping refresh step..." -ForegroundColor Yellow
            exit 0
        }
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

    Write-Host "Dataset refresh initiated" -ForegroundColor Green

    # Poll for refresh status
    Write-Host ""
    Write-Host "Monitoring refresh status..."
    Write-Host "(Timeout: $TimeoutMinutes minutes)"

    $maxAttempts = $TimeoutMinutes * 6  # Check every 10 seconds
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

            $elapsedMinutes = [math]::Round(($attempt * 10) / 60, 1)
            Write-Host "  [$elapsedMinutes min] Status: $currentStatus"

            if ($currentStatus -eq "Completed") {
                Write-Host ""
                Write-Host "================================================" -ForegroundColor Green
                Write-Host "Dataset refresh completed successfully!" -ForegroundColor Green
                Write-Host "================================================" -ForegroundColor Green
                Write-Host "Duration: $elapsedMinutes minutes"
                $refreshCompleted = $true
                break
            }
            elseif ($currentStatus -eq "Failed") {
                Write-Host ""
                Write-Host "================================================" -ForegroundColor Red
                Write-Host "Dataset refresh FAILED" -ForegroundColor Red
                Write-Host "================================================" -ForegroundColor Red

                # Get error details
                if ($latestRefresh.serviceExceptionJson) {
                    try {
                        $errorJson = $latestRefresh.serviceExceptionJson | ConvertFrom-Json
                        Write-Host "Error: $($errorJson.errorDescription)" -ForegroundColor Red
                    }
                    catch {
                        Write-Host "Error details: $($latestRefresh.serviceExceptionJson)" -ForegroundColor Red
                    }
                }

                $refreshFailed = $true
                break
            }
        }
        catch {
            Write-Warning "Error checking refresh status: $($_.Exception.Message)"
        }

    } while ($attempt -lt $maxAttempts -and $currentStatus -in @("Unknown", "InProgress", $null))

    # Handle timeout
    if (-not $refreshCompleted -and -not $refreshFailed) {
        Write-Host ""
        Write-Warning "Refresh status check timed out after $TimeoutMinutes minutes"
        Write-Warning "The refresh may still be in progress"
        Write-Host "Check Power BI Service for current refresh status" -ForegroundColor Yellow
    }

    # Exit codes
    if ($refreshCompleted) {
        exit 0
    }
    elseif ($refreshFailed) {
        Write-Host ""
        Write-Host "Common refresh failure reasons:" -ForegroundColor Cyan
        Write-Host "  1. Gateway not bound to dataset"
        Write-Host "  2. Gateway credentials not configured"
        Write-Host "  3. Gateway is offline"
        Write-Host "  4. SharePoint file not accessible"
        Write-Host "  5. Parameter values incorrect"
        Write-Host ""
        Write-Host "Solution: Ensure gateway binding step completed successfully" -ForegroundColor Yellow
        exit 1
    }
    else {
        # Timeout - not necessarily a failure
        exit 0
    }
}
catch {
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Red
    Write-Error "Could not trigger dataset refresh"
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
    Write-Host "This is likely a credentials issue." -ForegroundColor Yellow
    Write-Host "Ensure the gateway binding step completed successfully." -ForegroundColor Yellow
    Write-Host ""

    exit 1
}