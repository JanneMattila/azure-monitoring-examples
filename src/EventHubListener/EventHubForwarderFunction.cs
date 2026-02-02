using Azure.Messaging.EventHubs;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;

namespace EventHubListener;

public class EventHubForwarderFunction
{
    private static readonly HttpClient _client = new();
    private static readonly string? _address = Environment.GetEnvironmentVariable("FORWARD_ADDRESS");
    private static readonly string? _localPath = Environment.GetEnvironmentVariable("LOCAL_PATH");

    private readonly ILogger<EventHubForwarderFunction> _logger;

    public EventHubForwarderFunction(ILogger<EventHubForwarderFunction> logger)
    {
        _logger = logger;
    }

    /*
     * Note: 
     * You need to handle error scenarios much better, 
     * so that you don't drop any events. 
     * 
     * Example: Azure Storage Queue and dead lettering (64kB message size limit!)
     * https://docs.microsoft.com/en-us/azure/architecture/reference-architectures/serverless/event-processing
     * Example in GitHub:
     * https://github.com/mspnp/serverless-reference-implementation/blob/v0.1.0/src/DroneTelemetry/DroneTelemetryFunctionApp/RawTelemetryFunction.cs#L32
     * 
     * Alternative: Use Azure Storage Blob etc.
     */
    [Function("EventHubForwarderFunction")]
    public async Task Run(
        [EventHubTrigger("forwarder", Connection = "EventHubConnectionAppSetting", ConsumerGroup = "forwarder")]
        EventData[] events)
    {
        var exceptions = new List<Exception>();
        foreach (var eventData in events)
        {
            try
            {
                var messageBody = Encoding.UTF8.GetString(eventData.Body.ToArray(), 0, eventData.Body.Length);
                _logger.LogInformation("Forwarder function processing event: {MessageBody}", messageBody);

                if (!string.IsNullOrEmpty(_address))
                {
                    await _client.PostAsJsonAsync(_address, messageBody);
                }
                if (!string.IsNullOrEmpty(_localPath))
                {
                    await SaveRecordsByCategoryAsync(messageBody);
                }
            }
            catch (Exception e)
            {
                exceptions.Add(e);
            }
        }

        if (exceptions.Count > 1)
        {
            throw new AggregateException(exceptions);
        }

        if (exceptions.Count == 1)
        {
            throw exceptions.Single();
        }
    }

    private static readonly JsonSerializerOptions _jsonOptions = new() { WriteIndented = true };

    private async Task SaveRecordsByCategoryAsync(string messageBody)
    {
        using var document = JsonDocument.Parse(messageBody);
        var root = document.RootElement;

        if (root.TryGetProperty("records", out var records) && records.ValueKind == JsonValueKind.Array)
        {
            foreach (var record in records.EnumerateArray())
            {
                var folderName = GetFolderName(record);
                await SaveRecordAsync(record, folderName);
            }
        }
        else
        {
            // Single record - check for category/Type
            var folderName = GetFolderName(root);
            await SaveRecordAsync(root, folderName);
        }
    }

    private static string GetFolderName(JsonElement record)
    {
        if (record.TryGetProperty("category", out var categoryElement) &&
            categoryElement.GetString() is { } category)
        {
            return category;
        }

        if (record.TryGetProperty("Type", out var typeElement) &&
            typeElement.GetString() is { } type)
        {
            return type;
        }

        return "unknown";
    }

    private async Task SaveRecordAsync(JsonElement record, string folderName)
    {
        var folderPath = Path.Combine(_localPath!, folderName);
        Directory.CreateDirectory(folderPath);

        var filename = DateTime.UtcNow.ToString("yyyyMMddHHmmssfff") + "_" + Guid.NewGuid().ToString("N")[..8] + ".json";
        var filePath = Path.Combine(folderPath, filename);

        var formattedJson = JsonSerializer.Serialize(record, _jsonOptions);
        await File.WriteAllTextAsync(filePath, formattedJson);
    }
}
