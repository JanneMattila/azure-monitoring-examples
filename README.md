# Azure Monitoring examples

Few Azure Monitoring Examples

## Additinal notes

If you're configuring diagnostic settings for your resource, you might get following error:

```
Failed to update diagnostics for 'monitoringdemo'.{"code":"Conflict","message":"Data sink '/subscriptions/<subsriptionid>/resourceGroups/<resourcegroup>/providers/Microsoft.EventHub/namespaces/<eventhub>/authorizationrules/RootManageSharedAccessKey' is already used in diagnostic setting 'monitoring' for category 'AppExceptions'. Data sinks can't be reused in different settings on the same category for the same resource."}.
```

It means that you cannot create multiple diagnostic settings with same category targeting same destination.
And in event hub scenario it includes `authorizationrules/<your access key>` part.

Following is **not allowed**:

- `AppEvents` and `AppExceptions` to Event Hub namespace `ns` and event hub `eh1` using `RootManageSharedAccessKey`
- `AppDependencies` and `AppExceptions` to Event Hub `ns` and event hub`eh2` using `RootManageSharedAccessKey`

Following is **allowed**:

- `AppEvents` and `AppExceptions` to Event Hub namespace `ns` and event hub `eh1` using `eh1Policy`
- `AppDependencies` and `AppExceptions` to Event Hub `ns` and event hub`eh2` using `eh2Policy`
