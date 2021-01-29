using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.Extensions.Logging;
using System;
using System.Diagnostics;
using System.IO;
using System.Net.Http;
using System.Net.Http.Json;
using System.Threading.Tasks;

namespace EventHubListener
{
    public static class CorrelationExampleFunction
    {
        private static readonly HttpClient _client = new HttpClient();
        private static readonly string _address = Environment.GetEnvironmentVariable("FORWARD_ADDRESS");

        [FunctionName("Correlation")]
        public static async Task<IActionResult> Run(
            [HttpTrigger(AuthorizationLevel.Anonymous, "get", "post", Route = null)] HttpRequest req,
            ILogger log)
        {
            var parentId = req.Headers["x-ms-client-tracking-id"]; // Logic Apps sends this header

            var activity = new Activity("HttpTrigger Request");
            activity.SetParentId(parentId);
            activity.TraceStateString += "func=Correlation";
            activity.Start();

            log.LogInformation("C# HTTP trigger function processed a request.");

            using var streamReader = new StreamReader(req.Body);
            var body = await streamReader.ReadToEndAsync();
            await _client.PostAsJsonAsync(_address, body);

            return new OkResult();
        }
    }
}
