Connect-AzAccount
$subscriptionId = (Get-AzSubscription -SubscriptionName "Queens Network EA").SubscriptionId
Set-AzContext -Subscription $subscriptionId

# Password for the service principal
$pwd = "Xxxxxxx00*"
$secureStringPassword = ConvertTo-SecureString -String $pwd -AsPlainText -Force

# Create a new Azure AD application
$azureAdApplication = New-AzADApplication `
                        -DisplayName "Az Monitor Metrics" `
                        -HomePage "https://localhost/azure-monitor" `
                        -IdentifierUris "https://localhost/azure-monitor" `
                        -Password $secureStringPassword
$azureAdApplication = Get-AzADApplication -DisplayName "Az Monitor Metrics"

# Create a new service principal associated with the designated application
New-AzADServicePrincipal -ApplicationId $azureAdApplication.ApplicationId

# Assign Reader role to the newly created service principal
New-AzRoleAssignment -RoleDefinitionName Reader `
                          -ServicePrincipalName $azureAdApplication.ApplicationId.Guid


$azureAdApplication = Get-AzADApplication -IdentifierUri "https://localhost/azure-monitor"

$subscription = Get-AzSubscription -SubscriptionId $subscriptionId

$clientId = $azureAdApplication.ApplicationId.Guid
$tenantId = $subscription.TenantId
$authUrl = "https://login.microsoftonline.com/${tenantId}"

$AuthContext = [Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext]$authUrl
$cred = New-Object -TypeName Microsoft.IdentityModel.Clients.ActiveDirectory.ClientCredential -ArgumentList ($clientId, $pwd)

$result = $AuthContext.AcquireTokenAsync("https://management.core.windows.net/", $cred).GetAwaiter().GetResult()

$authHeader = @{
'Content-Type'='application/json'
'Accept'='application/json'
'Authorization'=$result.CreateAuthorizationHeader()
}


$request = "https://management.azure.com/subscriptions/${subscriptionId}/resourceGroups/${rg}/providers/Microsoft.ClassicCompute/domainNames/${resourceName}/slots/Production/roles/GloboStudio.Core.WebServices/metricDefinitions?api-version=2014-04-01"

Invoke-RestMethod -Uri $request `
                  -Headers $authHeader `
                  -Method Get `
                  -OutFile ".\metricdef-results.json" `
                  -Verbose

$resources = (Get-AzResource) | ? {$_.Type -eq "Microsoft.ClassicCompute/domainNames" -and $_.Name -like "WebFlowers*" -and $_.Location -eq "southcentralus"}

foreach($r in $resources){

$rg = $r.ResourceGroupName
$n = $r.ResourceName
    $filter = "(name.value eq 'Percentage CPU' or name.value eq 'Network In' or name.value eq 'Network Out' ) and startTime eq 2019-10-01T15:00:00Z and endTime eq 2019-10-08T07:00:00Z and timeGrain eq duration'PT5M'"
    $request = "https://management.azure.com/subscriptions/${subscriptionId}/resourceGroups/${rg}/providers/Microsoft.ClassicCompute/domainNames/${n}/slots/Production/roles/GloboStudio.Core.WebServices/metrics?`$filter=${filter}&api-version=2014-04-01"

Invoke-RestMethod -Uri $request `
                  -Headers $authHeader `
                  -Method Get `
                  -OutFile ".\DownloadData\${n}results.json" `
                  -Verbose

}



$resources2 = (Get-AzResource) | ? {$_.ResourceType -eq "Microsoft.ClassicCompute/domainNames" -and $_.Name -like "WebFlowers*" -and $_.Location -eq "southcentralus"}
Add-Content -Path "./southcentral-asset.csv" -Value "ResourceGruop,Name,Nodes,Size,Tier,File"
foreach($x in $resources2){
    $rg = $x.ResourceGroupName
    $n = $x.Name
    $r = Get-AzResource -ResourceGroupName $rg -ResourceType Microsoft.ClassicCompute/domainNames/slots/roles -ResourceName "${n}/Production/GloboStudio.Core.WebServices" -ApiVersion 2016-04-01

    $nodes = $r.Sku.Capacity
    $size = $r.Sku.Size
    $tier = $r.Sku.Tier
    $file="${n}results.json"
    Add-Content -Path "./southcentral-asset.csv" -Value "${rg},${n},${nodes},${size},${tier},${file}"
}
