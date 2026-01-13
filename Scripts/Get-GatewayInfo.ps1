param (
    [Parameter(Mandatory = $true)]
    [string]$ClientId,

    [Parameter(Mandatory = $true)]
    [string]$ClientSecret,

    [Parameter(Mandatory = $true)]
    [string]$TenantId
)

<#
.SYNOPSIS
    Helper script to retrieve Gateway and Datasource IDs for pipeline configuration.
    Run this ONCE to get the IDs needed for your Variable Groups.

.DESCRIPTION
    This script lists all available gateways and their datasources.
    Copy the GatewayId and DatasourceId to your Azure DevOps Variable Groups.

.EXAMPLE
    .\Get-GatewayInfo.ps1 -ClientId "xxx" -ClientSecret "xxx" -TenantId "xxx"
#>

Write-Host "============================================"
Write-Host "Gateway & Datasource Discovery Tool"
Write-Host "============================================"
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
    Write-Host ""

    # Get all gateways
    Write-Host "============================================"
    Write-Host "Available Gateways"
    Write-Host "============================================"
    
    $gatewaysUrl = "https://api.powerbi.com/v1.0/myorg/gateways"
    
    try {
        $gateways = Invoke-RestMethod -Method Get -Uri $gatewaysUrl -Headers $headers
        
        if ($gateways.value.Count -eq 0) {
            Write-Warning "No gateways found!"
            Write-Host ""
            Write-Host "You need to:" -ForegroundColor Yellow
            Write-Host "  1. Install On-Premises Data Gateway"
            Write-Host "  2. Configure it with Power BI Service"
            Write-Host "  3. Add SharePoint datasource to the gateway"
            Write-Host ""
            Write-Host "Download gateway: https://powerbi.microsoft.com/gateway/"
            exit 1
        }

        foreach ($gateway in $gateways.value) {
            Write-Host ""
            Write-Host "Gateway Name : $($gateway.name)" -ForegroundColor Cyan
            Write-Host "Gateway ID   : $($gateway.id)" -ForegroundColor Green
            Write-Host "Type         : $($gateway.type)"
            Write-Host "Status       : $($gateway.publicKey.exponent)"
            
            # Get datasources for this gateway
            Write-Host ""
            Write-Host "  Datasources:"
            Write-Host "  ------------"
            
            $datasourcesUrl = "https://api.powerbi.com/v1.0/myorg/gateways/$($gateway.id)/datasources"
            
            try {
                $datasources = Invoke-RestMethod -Method Get -Uri $datasourcesUrl -Headers $headers
                
                if ($datasources.value.Count -eq 0) {
                    Write-Host "  (No datasources configured)" -ForegroundColor Yellow
                }
                else {
                    foreach ($ds in $datasources.value) {
                        Write-Host ""
                        Write-Host "    Datasource Name : $($ds.datasourceName)" -ForegroundColor Cyan
                        Write-Host "    Datasource ID   : $($ds.id)" -ForegroundColor Green
                        Write-Host "    Type            : $($ds.datasourceType)"
                        Write-Host "    Connection      : $($ds.connectionDetails)"
                    }
                }
            }
            catch {
                Write-Warning "  Could not retrieve datasources: $($_.Exception.Message)"
            }
        }
    }
    catch {
        Write-Warning "Could not retrieve gateways: $($_.Exception.Message)"
        
        if ($_.Exception.Response.StatusCode -eq 401) {
            Write-Host ""
            Write-Host "Service Principal may not have gateway permissions." -ForegroundColor Yellow
            Write-Host "Add Service Principal as gateway admin in Power BI Service." -ForegroundColor Yellow
        }
    }

    Write-Host ""
    Write-Host "============================================"
    Write-Host "Next Steps"
    Write-Host "============================================"
    Write-Host ""
    Write-Host "1. Copy the Gateway ID and Datasource ID above"
    Write-Host ""
    Write-Host "2. Add to Azure DevOps Variable Groups:"
    Write-Host "   - PowerBI-Dev:"
    Write-Host "       GatewayId = <gateway-id>"
    Write-Host "       DatasourceId = <datasource-id>"
    Write-Host "   - PowerBI-Prod:"
    Write-Host "       GatewayId = <gateway-id>"
    Write-Host "       DatasourceId = <datasource-id>"
    Write-Host ""
    Write-Host "3. Run the pipeline - credentials will persist!"
    Write-Host ""
}
catch {
    Write-Error "Failed: $($_.Exception.Message)"
    exit 1
}