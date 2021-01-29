using Microsoft.Azure.EventHubs;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;

namespace EventHubListener
{
    public static class EventHubForwarderFunction
    {
        private static readonly HttpClient _client = new HttpClient();
        private static readonly string _address = Environment.GetEnvironmentVariable("FORWARD_ADDRESS");

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
        [FunctionName("EventHubForwarderFunction")]
        public static async Task Run(
            [EventHubTrigger("forwarder", Connection = "EventHubConnectionAppSetting", ConsumerGroup = "forwarder")]
            EventData[] events,
            ILogger log)
        {
            var exceptions = new List<Exception>();
            foreach (var eventData in events)
            {
                try
                {
                    var messageBody = Encoding.UTF8.GetString(eventData.Body.Array, eventData.Body.Offset, eventData.Body.Count);
                    log.LogInformation($"Forwarder function processing event: {messageBody}");
                    await _client.PostAsJsonAsync(_address, messageBody);
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
    }
}
