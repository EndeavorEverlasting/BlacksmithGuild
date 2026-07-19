using System;

namespace BlacksmithGuild.DevTools.Diagnostics
{
    public sealed class RuntimeSpanContext
    {
        public string RunId { get; private set; }
        public string SessionId { get; private set; }
        public string CommandId { get; private set; }
        public string CorrelationId { get; private set; }
        public string SpanId { get; private set; }
        public string ParentSpanId { get; private set; }
        public string Operation { get; private set; }
        public DateTime StartedUtc { get; private set; }

        private RuntimeSpanContext(
            string operation,
            RuntimeSpanContext parent,
            string sessionId,
            string commandId,
            string correlationId)
        {
            Operation = Bound(operation, 256) ?? "unknown";
            RunId = parent?.RunId ?? Guid.NewGuid().ToString("N");
            SessionId = Bound(sessionId ?? parent?.SessionId, 128);
            CommandId = Bound(commandId ?? parent?.CommandId, 128);
            CorrelationId = Bound(correlationId ?? parent?.CorrelationId ?? RunId, 128);
            SpanId = Guid.NewGuid().ToString("N");
            ParentSpanId = parent?.SpanId;
            StartedUtc = DateTime.UtcNow;
        }

        public static RuntimeSpanContext Create(
            string operation,
            RuntimeSpanContext parent = null,
            string sessionId = null,
            string commandId = null,
            string correlationId = null)
        {
            return new RuntimeSpanContext(operation, parent, sessionId, commandId, correlationId);
        }

        internal static string Bound(string value, int maximum)
        {
            if (string.IsNullOrEmpty(value))
            {
                return null;
            }

            return value.Length <= maximum ? value : value.Substring(0, maximum);
        }
    }
}
