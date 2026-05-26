# MonitorWriter

Sends JSON files from a local folder to a Log Analytics workspace via the Azure Monitor **Logs Ingestion API**, using `DefaultAzureCredential`. Field-name conversion (snake_case → PascalCase) is performed by the **DCR transformation** in Azure, not by this app.

## Configuration (`appsettings.json`)

```json
{
  "Monitor": {
	"DataCollectionEndpoint": "https://<your-dce>.<region>.ingest.monitor.azure.com",
	"DataCollectionRuleId": "dcr-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
	"StreamName": "CustomGitHubAuditLog_CL"
  },
  "SourceFolder": "C:\\temp\\EventHubListener\\unknown"
}
```

Override secrets via user secrets / environment variables (e.g. `Monitor__DataCollectionRuleId`).

## Authentication

Uses `DefaultAzureCredential` — works with Visual Studio sign-in, Azure CLI (`az login`), managed identity, or environment variables. The identity needs the **Monitoring Metrics Publisher** role on the DCR.

## Run

```pwsh
dotnet run --project src/MonitorWriter
```

The app reads every `*.json` file in `SourceFolder` and sends each as a record with the original snake_case keys. The DCR transforms the field names.

---

## Create the DCR and custom table (Azure Portal)

The repo includes [`sample-schema.json`](./sample-schema.json) — a single JSON record containing **every field** seen across the sample data (62 fields, including nested objects/arrays). Use it to bootstrap the custom table so the DCR stream declaration covers all source columns.

### 1. Create a Data Collection Endpoint (DCE)

Azure Portal → **Monitor** → **Data Collection Endpoints** → **Create**. Pick the same region as your Log Analytics workspace. Note the **Logs ingestion URI** for `appsettings.json`.

### 2. Create the custom table + DCR

1. Log Analytics workspace → **Tables** → **Create** → **New custom log (DCR-based)**.
2. Name the table (e.g. `CustomGitHubAuditLog` — the portal appends `_CL`).
3. Create a new DCR and select the DCE from step 1.
4. **Schema and transformation** → **Browse for files** → upload [`sample-schema.json`](./sample-schema.json).
   - The wizard infers all 62 source columns with the correct types (including `dynamic` for `actor_location`, `config`, `events`, `repositories_added`, `repositories_added_names`).
5. **Transformation editor** → paste the [KQL](#dcr-transformation-kql) below. Run it to confirm the schema preview, then **Apply**.
6. **Review + create** to provision the table and DCR.

### 3. Grant ingestion permissions

DCR → **Access control (IAM)** → assign **Monitoring Metrics Publisher** to the identity that will run this app (your user for Visual Studio / Azure CLI, or the managed identity).

### 4. Collect the DCR immutable ID

DCR → **Overview** → **JSON View** → copy the `immutableId` (`dcr-…`) into `appsettings.json`.

## DCR Transformation KQL

Sets `TimeGenerated` from `@timestamp` (Unix epoch ms) and renames every snake_case field to PascalCase. Casts nested values into `dynamic` columns.

```kql
source
| extend _ts = tolong(['@timestamp'])
| extend _created = tolong(created_at)
| extend TimeGenerated = iff(isnotnull(_ts),
							  datetime(1970-01-01) + _ts * 1ms,
							  now())
| project
	TimeGenerated,
	DocumentId                  = tostring(['_document_id']),
	Action                      = tostring(action),
	Active                      = tobool(active),
	Actor                       = tostring(actor),
	ActorId                     = tolong(actor_id),
	ActorIp                     = tostring(actor_ip),
	ActorIsBot                  = tobool(actor_is_bot),
	ActorLocation               = todynamic(actor_location),
	ApplicationClientId         = tostring(application_client_id),
	ApplicationId               = tolong(application_id),
	ApplicationName             = tostring(application_name),
	ApplicationType             = tostring(application_type),
	AuditLogStreamEnabled       = tobool(audit_log_stream_enabled),
	AuditLogStreamId            = tolong(audit_log_stream_id),
	AuditLogStreamResult        = tostring(audit_log_stream_result),
	AuditLogStreamSink          = tostring(audit_log_stream_sink),
	AuditLogStreamSinkDetails   = tostring(audit_log_stream_sink_details),
	Business                    = tostring(business),
	BusinessId                  = tolong(business_id),
	Config                      = todynamic(config),
	CreatedAt                   = iff(isnotnull(_created), datetime(1970-01-01) + _created * 1ms, datetime(null)),
	Events                      = todynamic(events),
	ExternalIdentityNameId      = tostring(external_identity_nameid),
	ExternalIdentityUsername    = tostring(external_identity_username),
	HashedToken                 = tostring(hashed_token),
	HookId                      = tolong(hook_id),
	Integration                 = tostring(integration),
	Name                        = tostring(name),
	OauthApplicationId          = tolong(oauth_application_id),
	OauthApplicationName        = tostring(oauth_application_name),
	OauthCredentialType         = tostring(oauth_credential_type),
	OperationType               = tostring(operation_type),
	Org                         = tostring(org),
	OrgId                       = tolong(org_id),
	PreviousVisibility          = tostring(previous_visibility),
	ProgrammaticAccessType      = tostring(programmatic_access_type),
	PublicRepo                  = tobool(public_repo),
	QueryString                 = tostring(query_string),
	RateLimitRemaining          = tolong(rate_limit_remaining),
	Reason                      = tostring(reason),
	Repo                        = tostring(repo),
	RepoId                      = tolong(repo_id),
	RepositoriesAdded           = todynamic(repositories_added),
	RepositoriesAddedNames      = todynamic(repositories_added_names),
	RepositorySelection         = tostring(repository_selection),
	RequestAccessSecurityHeader = tostring(request_access_security_header),
	RequestBody                 = tostring(request_body),
	RequestCategory             = tostring(request_category),
	RequestId                   = tostring(request_id),
	RequestMethod               = tostring(request_method),
	Route                       = tostring(route),
	StatusCode                  = toint(status_code),
	Team                        = tostring(team),
	TeamType                    = tostring(team_type),
	TokenId                     = tolong(token_id),
	TokenScopes                 = tostring(token_scopes),
	UrlPath                     = tostring(url_path),
	User                        = tostring(user),
	UserAgent                   = tostring(user_agent),
	UserId                      = tolong(user_id),
	Visibility                  = tostring(visibility)
```

> **Note:** Source columns that don't exist on a given record return `null` — that's expected and safe. Nested objects (`actor_location`, `config`) and arrays (`events`, `repositories_added`, `repositories_added_names`) land in **`dynamic`** columns so you can query them with `parse_json` / `mv-expand` later.

### Custom table schema

Create the DCR-based custom log table with these columns:

| Column                      | Type     |
| --------------------------- | -------- |
| TimeGenerated               | datetime |
| DocumentId                  | string   |
| Action                      | string   |
| Active                      | bool     |
| Actor                       | string   |
| ActorId                     | long     |
| ActorIp                     | string   |
| ActorIsBot                  | bool     |
| ActorLocation               | dynamic  |
| ApplicationClientId         | string   |
| ApplicationId               | long     |
| ApplicationName             | string   |
| ApplicationType             | string   |
| AuditLogStreamEnabled       | bool     |
| AuditLogStreamId            | long     |
| AuditLogStreamResult        | string   |
| AuditLogStreamSink          | string   |
| AuditLogStreamSinkDetails   | string   |
| Business                    | string   |
| BusinessId                  | long     |
| Config                      | dynamic  |
| CreatedAt                   | datetime |
| Events                      | dynamic  |
| ExternalIdentityNameId      | string   |
| ExternalIdentityUsername    | string   |
| HashedToken                 | string   |
| HookId                      | long     |
| Integration                 | string   |
| Name                        | string   |
| OauthApplicationId          | long     |
| OauthApplicationName        | string   |
| OauthCredentialType         | string   |
| OperationType               | string   |
| Org                         | string   |
| OrgId                       | long     |
| PreviousVisibility          | string   |
| ProgrammaticAccessType      | string   |
| PublicRepo                  | bool     |
| QueryString                 | string   |
| RateLimitRemaining          | long     |
| Reason                      | string   |
| Repo                        | string   |
| RepoId                      | long     |
| RepositoriesAdded           | dynamic  |
| RepositoriesAddedNames      | dynamic  |
| RepositorySelection         | string   |
| RequestAccessSecurityHeader | string   |
| RequestBody                 | string   |
| RequestCategory             | string   |
| RequestId                   | string   |
| RequestMethod               | string   |
| Route                       | string   |
| StatusCode                  | int      |
| Team                        | string   |
| TeamType                    | string   |
| TokenId                     | long     |
| TokenScopes                 | string   |
| UrlPath                     | string   |
| User                        | string   |
| UserAgent                   | string   |
| UserId                      | long     |
| Visibility                  | string   |

> The wizard creates these columns automatically when you upload `sample-schema.json` plus the transformation KQL — this table is just a reference.

## Verify

```kql
CustomGitHubAuditLog_CL
| take 10
```

Allow up to 30 minutes after creating the role assignment before the first records appear.

## Querying nested data

`ActorLocation`, `Config`, `Events`, `RepositoriesAdded`, and `RepositoriesAddedNames` are stored as `dynamic`, so you can drill into them with property access or `mv-expand`.

```kql
// Count requests by actor country
CustomGitHubAuditLog_CL
| where isnotnull(ActorLocation)
| extend Country = tostring(ActorLocation.country_code)
| summarize count() by Country
```

```kql
// Expand audit log stream events into individual rows
CustomGitHubAuditLog_CL
| where Action == "business.update_audit_log_stream"
| mv-expand Events
| project TimeGenerated, Actor, Event = tostring(Events)
```

```kql
// Inspect config for hook/audit-stream changes
CustomGitHubAuditLog_CL
| where isnotnull(Config)
| project TimeGenerated, Action, Actor, Config
```

```kql
// List repositories added in install/permission events
CustomGitHubAuditLog_CL
| where isnotnull(RepositoriesAddedNames)
| mv-expand RepositoryName = RepositoriesAddedNames to typeof(string)
| project TimeGenerated, Actor, Action, RepositoryName
```
