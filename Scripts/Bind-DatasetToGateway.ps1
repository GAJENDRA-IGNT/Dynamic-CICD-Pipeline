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
    [string]$GatewayId,

    [Parameter(Mandatory = $true)]
    [string]$DatasourceId
)

Write-Host "============================================"
Write-Host "Binding Dataset to Gateway"
Write-Host "============================================"
Write-Host "Workspace ID   : $WorkspaceId"
Write-Host "Dataset ID     : $DatasetId"
Write-Host "Gateway ID     : $GatewayId"
Write-Host "Datasource ID  : $DatasourceId"
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

    # Get current datasources for the dataset
    Write-Host ""
    Write-Host "Checking current datasources..."
    
    $datasourcesUrl = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/datasets/$DatasetId/datasources"
    
    try {
        $currentDatasources = Invoke-RestMethod -Method Get -Uri $datasourcesUrl -Headers $headers
        Write-Host "Current datasources found: $($currentDatasources.value.Count)"
        
        foreach ($ds in $currentDatasources.value) {
            Write-Host "  - Type: $($ds.datasourceType), Gateway: $($ds.gatewayId)"
        }
    }
    catch {
        Write-Warning "Could not retrieve current datasources: $($_.Exception.Message)"
    }

    # Bind dataset to gateway
    Write-Host ""
    Write-Host "Binding dataset to gateway..."
    
    $bindUrl = "https://api.powerbi.com/v1.0/myorg/groups/$WorkspaceId/datasets/$DatasetId/Default.BindToGateway"

    $bindBody = @{
        gatewayObjectId    = $GatewayId
        datasourceObjectIds = @($DatasourceId)
    } | ConvertTo-Json -Depth 3

    Write-Host "Request body: $bindBody"

    try {
        Invoke-RestMethod -Method Post -Uri $bindUrl -Headers $headers -Body $bindBody

        Write-Host ""
        Write-Host "================================================" -ForegroundColor Green
        Write-Host "Dataset successfully bound to gateway!" -ForegroundColor Green
        Write-Host "================================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "Gateway credentials will now be used for refresh." -ForegroundColor Green
        Write-Host "No manual credential configuration needed!" -ForegroundColor Green
    }
    catch {
        $errorMessage = $_.Exception.Message
        
        # Check if already bound
        if ($errorMessage -match "already bound" -or $errorMessage -match "same gateway") {
            Write-Host ""
            Write-Host "Dataset is already bound to this gateway" -ForegroundColor Yellow
            Write-Host "Continuing..." -ForegroundColor Yellow
        }
        else {
            throw $_
        }
    }

    # Verify binding
    Write-Host ""
    Write-Host "Verifying gateway binding..."
    
    try {
        $verifyDatasources = Invoke-RestMethod -Method Get -Uri $datasourcesUrl -Headers $headers
        
        foreach ($ds in $verifyDatasources.value) {
            if ($ds.gatewayId -eq $GatewayId) {
                Write-Host "Verified: Dataset is bound to gateway $GatewayId" -ForegroundColor Green
            }
        }
    }
    catch {
        Write-Warning "Could not verify binding"
    }

    exit 0
}
catch {
    Write-Host ""
    Write-Host "================================================" -ForegroundColor Red
    Write-Error "Failed to bind dataset to gateway"
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
    Write-Host "  1. Verify Gateway ID and Datasource ID are correct"
    Write-Host "  2. Ensure gateway is online and accessible"
    Write-Host "  3. Verify datasource credentials are configured on gateway"
    Write-Host "  4. Check Service Principal has gateway permissions"
    Write-Host ""

    exit 1
}