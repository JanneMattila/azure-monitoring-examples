# Correlation in monitoring

## Logic Apps & clientTrackingId

You can change your `clientTrackingId` (Correlation id)
in your Logic Apps for example based on agreed header name:

```json
"triggers": {
  "request": {
    "conditions": [
       {
         "expression": "@not(empty(triggerOutputs()?['headers']?['your_correlation_header']))"
       }
    ],
    "correlation": {
      "clientTrackingId": "@{triggerOutputs()['headers']['your_correlation_header']}"
    },
    "inputs": {
      "method": "GET",
      "schema": {}
    },
    "kind": "Http",
    "type": "Request"
  }
}
```

Example usage:

```json
"HTTP": {
  "inputs": {
    "body": {
      "text": "Your headers for correlation identifier"
    },
    "headers": {
      "your_correlation_header": "@{trigger().clientTrackingId}",
    },
    "method": "POST",
    "uri": "https://api.contoso.com/api/echo"
  },
  "runAfter": {},
  "type": "Http"
}
```

## Logic Apps Anywhere

Logic Apps Anywhere integrates with App Insights and
is capable of using [correlation headers using W3C TraceContext](https://docs.microsoft.com/en-us/azure/azure-monitor/app/correlation#correlation-headers-using-w3c-tracecontext)
like `traceparent`.

This works also when calling from Logic App to another
Logic App or to Azure Function. 

Example architecture:

<img src="https://user-images.githubusercontent.com/2357647/106308884-067f6600-626a-11eb-8475-338661bcbe6b.png" width="80%" height="80%" alt="Correlation example architecture" />

Logic Apps workflow `wf1` calls another workflow `wf2` which
in turn calls Azure Function named `correlation`.

Example header passed in the calls:

```
traceparent: 00-3ed28e6b61c2c14fa054645c3773aa1e-4bc37e57fc6b6e46-00
```

Notice [format](https://www.w3.org/TR/trace-context/#trace-context-http-headers-format):
`<version>-<trace-id>-<parent-id>-<trace-flags>`

You can now use this in information in your queries:

```sql
AppRequests
| where OperationId == "3ed28e6b61c2c14fa054645c3773aa1e"
| order by TimeGenerated asc
```

Query result:

| TimeGenerated [UTC]       | OperationName             | Url                                | Success | ResultCode |
|---------------------------|---------------------------|------------------------------------|---------|------------|
| 1/29/2021, 5:10:10.993 PM | wf1                       | .../api/wf1/triggers/manual/invoke | true    | 200        |
| 1/29/2021, 5:10:11.049 PM | wf1.manual                |                                    | true    | 0          |
| 1/29/2021, 5:10:11.077 PM | wf1.Invoke_wf2            |                                    | true    | 0          |
| 1/29/2021, 5:10:11.088 PM | wf2.manual                |                                    | true    | 0          |
| 1/29/2021, 5:10:11.103 PM | wf2.Invoke_Azure_Function |                                    | true    | 0          |
| 1/29/2021, 5:10:11.166 PM | correlation               | .../api/correlation                | true    | 200        |
| 1/29/2021, 5:10:11.257 PM | wf2.Response_from_wf2     |                                    | true    | 0          |
| 1/29/2021, 5:10:11.286 PM | wf1.Response_from_wf1     |                                    | true    | 0          |
