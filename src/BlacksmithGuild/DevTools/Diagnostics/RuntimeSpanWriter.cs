using System;
using System.Reflection;
using System.Text;
using BlacksmithGuild.DevTools.Automation;

namespace BlacksmithGuild.DevTools.Diagnostics
{
    public static class RuntimeSpanWriter
    {
        private const int MaximumExceptionText = 512;

        public static void WriteStarted(RuntimeSpanContext context, string expectedSignal, RuntimeStateSnapshot preState)
        {
            Write(context, AutomationRuntimeEventEmitter.SpanStarted, null, expectedSignal, null, preState, null);
        }

        public static void WriteTerminal(
            RuntimeSpanContext context,
            string type,
            string terminalStatus,
            string observedSignal,
            RuntimeStateSnapshot postState,
            Exception exception)
        {
            Write(context, type, terminalStatus, null, observedSignal, postState, exception);
        }

        private static void Write(
            RuntimeSpanContext context,
            string type,
            string terminalStatus,
            string expectedSignal,
            string observedSignal,
            RuntimeStateSnapshot state,
            Exception exception)
        {
            if (context == null)
            {
                return;
            }

            try
            {
                var payload = new StringBuilder("{");
                Append(payload, "runId", context.RunId);
                Append(payload, "sessionId", context.SessionId);
                Append(payload, "commandId", context.CommandId);
                Append(payload, "correlationId", context.CorrelationId);
                Append(payload, "spanId", context.SpanId);
                Append(payload, "parentSpanId", context.ParentSpanId);
                Append(payload, "operation", context.Operation);
                Append(payload, "startedUtc", context.StartedUtc.ToString("o"));
                Append(payload, "completedUtc", terminalStatus == null ? null : DateTime.UtcNow.ToString("o"));
                Append(payload, "terminalStatus", terminalStatus);
                Append(payload, "expectedSignal", RuntimeSpanContext.Bound(expectedSignal, 256));
                Append(payload, "observedSignal", RuntimeSpanContext.Bound(observedSignal, 256));
                AppendRaw(payload, terminalStatus == null ? "preState" : "postState", state == null ? "null" : state.ToJson());
                Append(payload, "exception", BoundedException(exception));
                Append(payload, "assemblyIdentity", AssemblyIdentity());
                if (payload[payload.Length - 1] == ',')
                {
                    payload.Length--;
                }

                payload.Append("}");
                AutomationRuntimeEventEmitter.Emit(
                    type,
                    sessionId: context.SessionId,
                    boundaryId: context.SpanId,
                    reason: terminalStatus,
                    payloadJson: payload.ToString(),
                    source: "in_process_span");
            }
            catch
            {
                // Diagnostics must never alter game control flow.
            }
        }

        private static string AssemblyIdentity()
        {
            try
            {
                return Assembly.GetExecutingAssembly().GetName().Name + "@" + Assembly.GetExecutingAssembly().GetName().Version;
            }
            catch
            {
                return null;
            }
        }

        private static string BoundedException(Exception exception)
        {
            if (exception == null)
            {
                return null;
            }

            var text = exception.GetType().Name + ": " + exception.Message;
            text = text.Replace("\r", " ").Replace("\n", " ");
            return RuntimeSpanContext.Bound(text, MaximumExceptionText);
        }

        private static void Append(StringBuilder builder, string name, string value)
        {
            builder.Append("\"").Append(name).Append("\":");
            builder.Append(value == null ? "null" : "\"" + Escape(value) + "\"").Append(",");
        }

        private static void AppendRaw(StringBuilder builder, string name, string value)
        {
            builder.Append("\"").Append(name).Append("\":").Append(value ?? "null").Append(",");
        }

        private static string Escape(string value) =>
            (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"").Replace("\r", "\\r").Replace("\n", "\\n");
    }
}
