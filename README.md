# Azure Monitoring examples

:construction: This content is **work in progress**.

Designing complete monitoring solution requires that you
understand the different scenarios and requirements,
so that you can prepare you Azure components
to match those requirements. Here are few thoughts
how to approach that planning.

## Planning

Typical monitoring solution is some form of combination of
different scenarios listed below. Therefore, it makes
sense to look them from scenario point of view.

You should know your requirements because ultimately
they impact your monitoring solution.

_Example:_ You're required to store certain application events
for 5 years -> You have to think long-term storage such as
Azure Storage account for storing those events.
Log Analytics Workspace maximum data retension is
[2 years](https://docs.microsoft.com/en-us/azure/azure-monitor/platform/manage-cost-storage#change-the-data-retention-period) (730 days).

_Example:_ You need to provide chart about certain Azure
resource metric data for last 8 months -> You have to
store this metric data to logs since metric data is only available for
[3 months](https://docs.microsoft.com/en-us/azure/azure-monitor/platform/data-platform-metrics#retention-of-metrics) (93 days). 

If you have hard time planning your overall solution
from technical components then you can try to use
[event modeling](https://eventmodeling.org/posts/what-is-event-modeling/)
for help.

### Implementation steps

When planning and implementing your monitoring scenarios you typically follow these steps:

1. Enable data collection
2. Find correct data
3. Create alert from data
4. Create action from alert
5. Visualize
6. Test
7. Automate

#### 1. Enable data collection

> What you can't see, you can't measure. What you can't measure, you can't improve.

Quote from [Enterprise-scale architecture operational design principles / Management and monitoring](https://docs.microsoft.com/en-us/learn/modules/enterprise-scale-operations/2-management-monitoring)

TBD

#### 2. Find correct data

TBD

#### 3. Create alert from data

TBD

#### 3. Create alert from data

TBD

#### 4. Create action from alert

TBD

#### 5. Visualize

TBD

#### 6. Test

TBD

#### 7. Automate

TBD

## Scenarios

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

If you have single application already using Application Insights, then you can have similar query based alert in that:

<img src="https://user-images.githubusercontent.com/2357647/106034836-149f7c00-60dc-11eb-9bf8-f4d416ba8abb.png" width="70%" height="70%" alt="App Insights Log Alert" />

### Scenario 2

#### What

Create metric based alerts for Azure resources

#### How

- Find Azure resource [metric](https://docs.microsoft.com/en-us/azure/azure-monitor/platform/metrics-supported) that you want to monitor
- Create metric based alert to that resource

Here are few examples:

Failed runs in Logic Apps resource:

<img src="https://user-images.githubusercontent.com/2357647/106115829-d9dc2900-6159-11eb-9c06-0b3c1a4ac810.png" width="70%" height="70%" alt="App Insights Metric Alert" />

Exception count in Application Insights resource:

<img src="https://user-images.githubusercontent.com/2357647/106115622-a4cfd680-6159-11eb-8a66-4399d057a6b1.png" width="70%" height="70%" alt="App Insights Metric Alert" />

DTU ([Database transaction unit](https://docs.microsoft.com/en-us/azure/azure-sql/database/purchasing-models)) usage is high
in SQL Database:

<img src="https://user-images.githubusercontent.com/2357647/106122675-a30a1100-6161-11eb-9084-9fef293ea3fd.png" width="70%" height="70%" alt="App Insights Metric Alert" />

#### Notes

- Alerts have [state](https://docs.microsoft.com/en-us/azure/azure-monitor/platform/alerts-overview#manage-alerts)
and platform automatically changes the state from `Fired` to `Resolved` when condition clears
  - You get notified when state changes to `Resolved`
- Limited filtering available for metrics (dimensions of metrics)
  - Example: You cannot create alert only for specific exceptions in App Insights using metric alerts
- Metric based alert costs $0.10 per monitored signal per month
- Use [common alert schema](https://docs.microsoft.com/en-us/azure/azure-monitor/platform/alerts-common-schema)

### Scenario 3

#### What

Enable custom processing based on Azure resource metric or log data

#### How

- Create Event Hub and Azure Functions resources
- Azure Function listens incoming data from Event Hub
- Deploy custom processing logic to Azure Functions
- Set `Diagnostic settings` in Azure resources to send data to your Event Hub

Here is example:

<img src="https://user-images.githubusercontent.com/2357647/106141949-837ee280-6179-11eb-8388-85815991ec8d.png" width="70%" height="70%" alt="Diagnostic Settings and Event Hub Custom Forwarder" />

#### Notes

- Requires custom development
  - Simplified example about Event Hub Forwarder
  [src/EventHubListener/EventHubForwarderFunction.cs](src/EventHubListener/EventHubForwarderFunction.cs)
- Full flexibility and control
- Diagnostic settings can be be managed in scale using Azure Policies

### Scenario 4

#### What

Minimize latency from event to action

#### How

- Create Event Hub and Azure Functions resources
- Azure Function listens incoming data from Event Hub
- Deploy custom processing logic to Azure Functions
- Use custom endpoint directly from you applications

Here is example:

<img src="https://user-images.githubusercontent.com/2357647/106034681-e0c45680-60db-11eb-8b8c-2a789da818b8.png" width="70%" height="70%" alt="Custom diagnostics with Event Hub Custom Forwarder" />

#### Notes

- Heavy on custom development
- Very low latency
- Makes sense if action is automated
  - E.g. Call API when certain event or metric threshold is met
  - Hard to justify, if action causes humans to do corrective actions
- You need to create reusable code do this in multiple applications
  - E.g. Nuget package for your .NET apps

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
