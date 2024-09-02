Login-AzAccount

$location = "swedencentral"
$resourceGroupName = "rg-mma-to-ama"
$workspaceName = "logama"

# Verify the context
Get-AzContext

New-AzResourceGroup -Name $resourceGroupName -Location $location -Force
New-AzResourceGroup -Name "rg-mma-to-ama-vms" -Location $location  -Force # For VMs

# Create a Log Analytics workspace(s)
New-AzOperationalInsightsWorkspace -ResourceGroupName $resourceGroupName -Name "logmma" -Location $location

$workspace = New-AzOperationalInsightsWorkspace -ResourceGroupName $resourceGroupName -Name $workspaceName -Location $location
$workspace.ResourceId

# Get VM Insights ARM template
Invoke-WebRequest https://github.com/Azure/AzureMonitorForVMs-ArmTemplates/releases/download/vmi_ama_ga/DeployDcr.zip -OutFile DeployDcr.zip
Expand-Archive -Path DeployDcr.zip -DestinationPath .

# Fill in the parameters in the PerfAndMapDcrParameters.json file
$configuration = Get-Content ./DeployDcr/PerfAndMapDcr/DeployDcrParameters.json | ConvertFrom-Json
$configuration.parameters.WorkspaceResourceId.value = $workspace.ResourceId
$configuration.parameters.WorkspaceLocation.value = $location
$configuration.parameters.userGivenDcrName.value = $null
$configuration | ConvertTo-Json > ./DeployDcr/PerfAndMapDcr/DeployDcrParameters.json
Get-Content ./DeployDcr/PerfAndMapDcr/DeployDcrParameters.json

# Deploy the VM Insights DCR
New-AzResourceGroupDeployment `
    -DeploymentName "AMA-VMInsights-DCR" `
    -ResourceGroupName $resourceGroupName `
    -TemplateFile ./DeployDcr/PerfAndMapDcr/DeployDcrTemplate.json `
    -TemplateParameterFile ./DeployDcr/PerfAndMapDcr/DeployDcrParameters.json `
    -Verbose

# Create user-assigned managed identity for VMs
New-AzUserAssignedIdentity -ResourceGroupName $resourceGroupName -Name "id-vm-shared" -Location $location

# Create user-assigned managed identity for policy assignment
$managedIdentity = New-AzUserAssignedIdentity -ResourceGroupName $resourceGroupName -Name "id-policy-assignment" -Location $location
$managedIdentity

$subscriptionId = (Get-AzContext).Subscription.Id

# Grant the managed identity role assignment to subscription
New-AzRoleAssignment -Scope "/subscriptions/$subscriptionId" -RoleDefinitionName "Contributor" -ObjectId  $managedIdentity.PrincipalId

# ------------

Start-AzPolicyComplianceScan -ResourceGroupName "rg-mma-to-ama-vms"

# ------------

Invoke-WebRequest https://raw.githubusercontent.com/microsoft/AzureMonitorCommunity/master/Azure%20Services/Azure%20Monitor/Agents/Migration%20Tools/DCR%20Config%20Generator/WorkspaceConfigToDCRMigrationTool.ps1 -OutFile WorkspaceConfigToDCRMigrationTool.ps1

Get-AzVM
$virtualMachines = Get-AzVM -ResourceGroupName "rg-mma-to-ama-vms"

$virtualMachines | ForEach-Object {
    $_.Identity
}

$workspaces = Get-AzOperationalInsightsWorkspace | Select-Object -Property ResourceGroupName, Name

$workspaces | ForEach-Object {
    $rgName = $_.ResourceGroupName
    $workspaceName = $_.Name
    $dcrName = "DCR-$workspaceName"
    $outputFolderPath = "C:\Temp\DCR\$workspaceName"
    mkdir $outputFolderPath -Force
    .\WorkspaceConfigToDCRMigrationTool.ps1 -SubscriptionId $subscriptionId -ResourceGroupName $rgName -WorkspaceName $workspaceName -DCRName $dcrName -OutputFolder $outputFolderPath
}

$rgName = $workspaces[1].ResourceGroupName
$workspaceName = $workspaces[1].Name
$dcrName = "DCR-$workspaceName"
$outputFolderPath = "C:\Temp\DCR\$workspaceName"

mkdir $outputFolderPath -Force

.\WorkspaceConfigToDCRMigrationTool.ps1 -SubscriptionId $subscriptionId -ResourceGroupName $rgName -WorkspaceName $workspaceName -DCRName $dcrName -OutputFolder $outputFolderPath

explorer $outputFolderPath

# Clean up
# Copy script from:
# https://learn.microsoft.com/en-us/azure/azure-monitor/agents/azure-monitor-agent-mma-removal-tool
# LogAnalyticsAgentUninstallUtilityScript.ps1

# Script uses Azure CLI, so check the context
az login
az account show

# To get inventory:
.\LogAnalyticsAgentUninstallUtilityScript.ps1 GetInventory

Start-Process LogAnalyticsAgentExtensionInventory.csv

# To remove MMA:
.\LogAnalyticsAgentUninstallUtilityScript.ps1 UninstallExtension
