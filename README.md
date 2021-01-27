# Azure Monitoring examples

:construction: This content is **work in progress**.

Designing complete monitoring solution requires that you
understand the different scenarios and requirements,
so that you can prepare you Azure components
to match those requirements. Here are few thoughts
how to approach that planning.

## Scenarios

### Implementation steps

When planning and implementing your monitoring scenarios you typically follow these steps:

1. Enable data collection
2. Find correct data
3. Create alert from data
4. Create action from alert
5. _Optional_ Visualize
6. Test
7. Automate

### Scenario 1

#### What

Collect data from Azure resources with minimal effort
and get alerted in specific conditions.

#### How

- Create Log Analytics workspace for logs
- Set `Diagnostic settings` in Azure resources to
send data to Log Analytics workspace
- Create log based query alert to workspace

<img src="https://user-images.githubusercontent.com/2357647/106002186-81554f00-60b9-11eb-81a7-7606e17af9d8.png" width="50%" height="50%" alt="Monitoring architecture" />

Log query can be then used for creating alerts:

<img src="https://user-images.githubusercontent.com/2357647/106003072-823ab080-60ba-11eb-9072-788c6919ab1c.png" width="70%" height="70%" alt="Log Analytics log query alert" />

In above example `webhook` is called when alert is fired.

Read more about all available actions in [action groups](https://docs.microsoft.com/en-us/azure/azure-monitor/platform/action-groups).

Here are few example queries:

Find failed Logic Apps integrations:

```sql
AzureDiagnostics 
| where OperationName == "Microsoft.Logic/workflows/workflowRunCompleted"
| where Level == "Error"
```

Find specific custom exception:

```sql
AppExceptions
| where ExceptionType == "ContosoRetailBackendException"
```

#### Notes

- Can be managed in scale using Azure Policies
  - [Enterprise-Scale and Azure Policy for policy-driven governance](https://techcommunity.microsoft.com/t5/azure-architecture-blog/enterprise-scale-and-azure-policy-for-policy-driven-governance/ba-p/1614060)
  - [Deploy Enterprise-Scale Azure policies](https://github.com/Azure/Enterprise-Scale/tree/main/azopsreference)
- Some resources support [resources specific](https://docs.microsoft.com/en-us/azure/azure-monitor/reference/tables/azurediagnostics#azure-diagnostics-mode-or-resource-specific-mode) schema
- Application Insights can use workspace for data storage (don't need to use diagnostic setting in that case)
- Each 5-min interval based query alert costs $1.50 per month
  - Try to create `general` query alerts (_"Find Logic Apps Errors"_) vs. 
    very specific query which get multiplied by customer by product by _xyz_ (causing _n_ number of queries)

### Other scenario(s)

<img src="https://user-images.githubusercontent.com/2357647/106034836-149f7c00-60dc-11eb-9bf8-f4d416ba8abb.png" width="70%" height="70%" alt="App Insights Log Alert" />

<img src="https://user-images.githubusercontent.com/2357647/106034472-9fcc4200-60db-11eb-9642-f4c3fe5bc556.png" width="70%" height="70%" alt="App Insights Metric Alert" />

<img src="https://user-images.githubusercontent.com/2357647/106034592-c25e5b00-60db-11eb-8f94-a9cabcd148cf.png" width="70%" height="70%" alt="Diagnostic Settings and Event Hub Custom Forwarder" />

<img src="https://user-images.githubusercontent.com/2357647/106034681-e0c45680-60db-11eb-8b8c-2a789da818b8.png" width="70%" height="70%" alt="Custom diagnostics with Event Hub Custom Forwarder" />

## Additinal notes

### Pricing

[Azure Monitor Pricing](https://azure.microsoft.com/en-us/pricing/details/monitor/)

[Azure Pricing Calculator](https://azure.microsoft.com/en-us/pricing/calculator/)

### Data ingestion

[Log data ingestion time in Azure Monitor](https://docs.microsoft.com/en-us/azure/azure-monitor/platform/data-ingestion-time)

[Alert triggered by partial data](https://docs.microsoft.com/en-us/azure/azure-monitor/platform/alerts-troubleshoot-log#alert-triggered-by-partial-data)

### Limits

You can have up to 5 diagnostic settings applied to Azure resource.

[Azure Monitor service limits](https://docs.microsoft.com/en-us/azure/azure-monitor/service-limits#log-analytics-workspaces)

### Data sink conflict

If you're configuring diagnostic settings for your resource, you might get following error:

```
Failed to update diagnostics for 'monitoringdemo'.
{
  "code":"Conflict",
  "message": "Data sink '/subscriptions/<id>/resourceGroups/<rg>/providers/Microsoft.EventHub/namespaces/<ns>/authorizationrules/RootManageSharedAccessKey'
  is already used in diagnostic setting 'monitoring' for category 'AppExceptions'.
  Data sinks can't be reused in different settings on the same category for the same resource."
}.
```

It means that you cannot create multiple diagnostic settings with same category targeting same destination.
And in event hub scenario it includes `authorizationrules/<your access key>` part.

Following is **not allowed**:

- `AppEvents` and `AppExceptions` to Event Hub namespace `ns` and event hub `eh1` using `RootManageSharedAccessKey`
- `AppDependencies` and `AppExceptions` to Event Hub `ns` and event hub`eh2` using `RootManageSharedAccessKey`

Following is **allowed**:

- `AppEvents` and `AppExceptions` to Event Hub namespace `ns` and event hub `eh1` using `eh1Policy`
- `AppDependencies` and `AppExceptions` to Event Hub `ns` and event hub`eh2` using `eh2Policy`
