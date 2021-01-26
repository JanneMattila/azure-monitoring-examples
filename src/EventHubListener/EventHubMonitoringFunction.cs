using Microsoft.Azure.EventHubs;
using Microsoft.Azure.WebJobs;
using Microsoft.Extensions.Logging;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace EventHubListener
{
    public static class EventHubMonitoringFunction
    {
        [FunctionName("EventHubMonitoringFunction")]
        public static async Task Run(
            [EventHubTrigger("monitoring", Connection = "EventHubConnectionAppSetting", ConsumerGroup = "monitoring")]
            EventData[] events, 
            ILogger log)
        {
            var exceptions = new List<Exception>();
            foreach (var eventData in events)
            {
                try
                {
                    string messageBody = Encoding.UTF8.GetString(eventData.Body.Array, eventData.Body.Offset, eventData.Body.Count);

                    log.LogInformation($"C# Event Hub trigger function processed a message: {messageBody}");
                    await Task.Yield();
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
