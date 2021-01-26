Param (
    [Parameter(HelpMessage = "Deployment storage account resource group")] 
    [string] $DeploymentResourceGroupName = "rg-apimdeploy-local",

    [Parameter(HelpMessage = "Deployment storage account name")] 
    [string] $DeploymentStorageName = "apimdeploylocal2",

    [Parameter(HelpMessage = "Deployment container")] 
    [string] $DeploymentContainer = "local-func",

    [Parameter(HelpMessage = "Deployment target resource group")] 
    [string] $ResourceGroupName = "rg-apim4-local",

    [Parameter(HelpMessage = "Deployment target resource group location")] 
    [string] $Location = "North Europe",

    [Parameter(HelpMessage = "API Management Name")] 
    [string] $APIMName = "contosoapim4-local",

    [string] $Template = "azuredeploy.json",
    [string] $TemplateParameters = "$PSScriptRoot\azuredeploy.parameters.json",
    [switch] $PreserveDeploymentContainer
)

$ErrorActionPreference = "Stop"

$date = (Get-Date).ToString("yyyy-MM-dd-HH-mm-ss")
$deploymentName = "Local-$date"

if ([string]::IsNullOrEmpty($env:RELEASE_DEFINITIONNAME)) {
    Write-Host (@"
Not executing inside Azure DevOps Release Management.
Make sure you have done "Login-AzAccount" and
"Select-AzSubscription -SubscriptionName name"
so that script continues to work correctly for you.
"@)
}
else {
    $deploymentName = $env:RELEASE_RELEASENAME
}

# Deployment helper storage account
if ($null -eq (Get-AzResourceGroup -Name $DeploymentResourceGroupName -Location $Location -ErrorAction SilentlyContinue)) {
    Write-Warning "Resource group '$DeploymentResourceGroupName' doesn't exist and it will be created."
    New-AzResourceGroup -Name $DeploymentResourceGroupName -Location $Location -Verbose
    New-AzStorageAccount `
        -ResourceGroupName $DeploymentResourceGroupName `
        -Name $DeploymentStorageName `
        -Location $Location `
        -SkuName Standard_LRS `
        -EnableHttpsTrafficOnly
}

Set-AzCurrentStorageAccount -ResourceGroupName $DeploymentResourceGroupName -Name $DeploymentStorageName

if ($null -ne (Get-AzStorageContainer -Name $DeploymentContainer -ErrorAction SilentlyContinue)) {
    Write-Warning "Deployment storage container '$DeploymentContainer' exists and it will be removed."
    Remove-AzStorageContainer -Name $DeploymentContainer -Force
    Write-Host "Waiting for 30 seconds for the removal to finish."
    Start-Sleep 30
}

$container = $null
while ($null -eq $container) {
    $container = New-AzStorageContainer -Name $DeploymentContainer -ErrorAction SilentlyContinue
    if ($null -eq $container) {
        Write-Host "Waiting deployment storage container to be removed. Waiting for 10 seconds."
        Start-Sleep 10
    }
}

$container
$folder = "$PSScriptRoot\"
Get-ChildItem -File -Recurse $folder -Exclude *.ps1 `
| ForEach-Object { 
    $name = $_.FullName.Replace($folder, "")
    $properties = @{"ContentType" = "application/json" }

    Write-Host "Deploying file: $name"
    Set-AzStorageBlobContent -File $_.FullName -Blob $name -Container $DeploymentContainer -Properties $properties -Force
}

$templateUrl = (Get-AzStorageContainer -Container $DeploymentContainer).CloudBlobContainer.StorageUri.PrimaryUri.AbsoluteUri + "/"
$templateToken = New-AzStorageContainerSASToken -Name $DeploymentContainer -Permission r -ExpiryTime (Get-Date).AddMinutes(30.0)

# Target deployment resource group
if ($null -eq (Get-AzResourceGroup -Name $ResourceGroupName -Location $Location -ErrorAction SilentlyContinue)) {
    Write-Warning "Resource group '$ResourceGroupName' doesn't exist and it will be created."
    New-AzResourceGroup -Name $ResourceGroupName -Location $Location -Verbose
}

# Additional parameters that we pass to the template deployment
$additionalParameters = New-Object -TypeName hashtable
$additionalParameters['apimName'] = $APIMName
$additionalParameters['templateUrl'] = $templateUrl
$additionalParameters['templateToken'] = ConvertTo-SecureString -String $templateToken -AsPlainText

$result = New-AzResourceGroupDeployment `
    -DeploymentName $deploymentName `
    -ResourceGroupName $ResourceGroupName `
    -TemplateUri ($templateUrl + $Template + $templateToken) `
    -TemplateParameterFile $TemplateParameters `
    @additionalParameters `
    -Mode Complete -Force `
    -Verbose

if ($null -eq $result.Outputs.apimGateway) {
    Throw "Template deployment didn't return web app information correctly and therefore deployment is cancelled."
}

$result | Select-Object -ExcludeProperty TemplateLinkString

$apimGateway = $result.Outputs.apimGateway.value

# Publish variable to the Azure DevOps agents so that they
# can be used in follow-up tasks such as application deployment
Write-Host "##vso[task.setvariable variable=Custom.APIMGateway;]$apimGateway"

Write-Host "Validating that our *MANDATORY* API is up and running..."
$webAppUri = "$apimGateway/users"
$data = @{
    id      = 1
    name    = "Doe"
    address = @{
        street     = "My street 1"
        postalCode = "12345"
        city       = "My city"
        country    = "My country"
    }
}
$body = ConvertTo-Json $data
$running = 0
for ($i = 0; $i -lt 60; $i++) {
    try {
        $request = Invoke-WebRequest -Body $body -ContentType "application/json" -Method "POST" -DisableKeepAlive -Uri $webAppUri -ErrorAction SilentlyContinue
        Write-Host "API status code $($request.StatusCode)."

        if ($request.StatusCode -eq 200) {
            Write-Host "API is up and running."
            $running++
        }
    }
    catch {
        Start-Sleep -Seconds 3
    }

    if ($running -eq 1) {
        if (!$PreserveDeploymentContainer.IsPresent) {
            Write-Host "After successful deployment removing the deployment storage container..."
            Remove-AzStorageContainer -Name $DeploymentContainer -Force
        }
        return
    }
}

Throw "Mandatory API didn't respond on defined time."
