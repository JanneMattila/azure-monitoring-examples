using System.Text.Json.Nodes;
using Azure.Identity;
using Azure.Monitor.Ingestion;
using Microsoft.Extensions.Configuration;

var configuration = new ConfigurationBuilder()
    .SetBasePath(AppContext.BaseDirectory)
    .AddJsonFile("appsettings.json", optional: false)
    .AddEnvironmentVariables()
    .AddUserSecrets<Program>(optional: true)
    .Build();

var dceUri = configuration["Monitor:DataCollectionEndpoint"]
    ?? throw new InvalidOperationException("Monitor:DataCollectionEndpoint is missing.");
var ruleId = configuration["Monitor:DataCollectionRuleId"]
    ?? throw new InvalidOperationException("Monitor:DataCollectionRuleId is missing.");
var streamName = configuration["Monitor:StreamName"]
    ?? throw new InvalidOperationException("Monitor:StreamName is missing.");
var sourceFolder = configuration["SourceFolder"]
    ?? throw new InvalidOperationException("SourceFolder is missing.");

if (!Directory.Exists(sourceFolder))
{
    Console.Error.WriteLine($"Source folder not found: {sourceFolder}");
    return 1;
}

var files = Directory.GetFiles(sourceFolder, "*.json", SearchOption.TopDirectoryOnly);
Console.WriteLine($"Found {files.Length} file(s) in {sourceFolder}");

if (files.Length == 0)
{
    return 0;
}

var credential = new DefaultAzureCredential();
var client = new LogsIngestionClient(new Uri(dceUri), credential);

var records = new List<JsonObject>(files.Length);
foreach (var file in files)
{
    try
    {
        var json = await File.ReadAllTextAsync(file);
        var node = JsonNode.Parse(json);
        if (node is JsonObject obj)
        {
            records.Add(obj);
        }
        else
        {
            Console.WriteLine($"Skipping non-object JSON: {file}");
        }
    }
    catch (Exception ex)
    {
        Console.Error.WriteLine($"Failed to read {file}: {ex.Message}");
    }
}

Console.WriteLine($"Uploading {records.Count} record(s) to {streamName}...");

var response = await client.UploadAsync(ruleId, streamName, records);
if (response.IsError)
{
    Console.Error.WriteLine($"Upload failed: {response.Status} {response.ReasonPhrase}");
    return 2;
}

Console.WriteLine($"Upload completed: HTTP {response.Status}");
return 0;


