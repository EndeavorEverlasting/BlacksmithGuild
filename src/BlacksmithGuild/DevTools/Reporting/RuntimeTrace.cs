using System;
using System.Collections.Generic;
using System.Diagnostics;
using BlacksmithGuild.DevTools;

namespace BlacksmithGuild.DevTools.Reporting
{
    public static class RuntimeTrace
    {
        private static int _sequence;
        private static readonly HashSet<string> DeferOnceKeys =
            new HashSet<string>(StringComparer.Ordinal);

        private static readonly HashSet<string> SuppressOnceKeys =
            new HashSet<string>(StringComparer.Ordinal);

        private static readonly Dictionary<string, DateTime> SuppressIntervalLastUtc =
            new Dictionary<string, DateTime>(StringComparer.Ordinal);

        public static void Run(string area, string operation, Action action)
        {
            var seq = InterlockedIncrement();
            var path = LaunchPathInference.GetPathLabel();
            var sw = Stopwatch.StartNew();
            Log(seq, area, operation, "begin", path);
            CrashContextWriter.RecordBegin(seq, area, operation, path);

            try
            {
                action();
                sw.Stop();
                Log(seq, area, operation, "ok", path, sw.ElapsedMilliseconds);
                CrashContextWriter.RecordOk(seq, area, operation, path);
            }
            catch (Exception ex)
            {
                sw.Stop();
                LogFail(seq, area, operation, ex, path);
                CrashContextWriter.RecordFail(seq, area, operation, ex, path);
                throw;
            }
        }

        public static T Run<T>(string area, string operation, Func<T> func)
        {
            T result = default;
            Run(area, operation, () => { result = func(); });
            return result;
        }

        public static void LogFail(string area, string operation, Exception ex)
        {
            var seq = _sequence;
            LogFail(seq, area, operation, ex, LaunchPathInference.GetPathLabel());
            CrashContextWriter.RecordFail(seq, area, operation, ex, LaunchPathInference.GetPathLabel());
        }

        public static void LogDefer(string area, string operation, string reason)
        {
            var seq = InterlockedIncrement();
            var path = LaunchPathInference.GetPathLabel();
            LogDefer(seq, area, operation, reason, path);
            CrashContextWriter.RecordDefer(seq, area, operation, reason, path);
        }

        public static void LogDeferOnce(string key, string area, string operation, string reason)
        {
            if (!DeferOnceKeys.Add(key))
            {
                return;
            }

            LogDefer(area, operation, reason);
        }

        public static void LogSuppressOnce(string key, string area, string operation, string reason)
        {
            if (!SuppressOnceKeys.Add(key))
            {
                return;
            }

            LogSuppress(area, operation, reason);
        }

        public static void LogSuppressInterval(
            string key,
            string area,
            string operation,
            string reason,
            double minIntervalSec)
        {
            var now = DateTime.UtcNow;
            if (SuppressIntervalLastUtc.TryGetValue(key, out var last)
                && (now - last).TotalSeconds < minIntervalSec)
            {
                return;
            }

            SuppressIntervalLastUtc[key] = now;
            LogSuppress(area, operation, reason);
        }

        public static void LogSuppress(string area, string operation, string reason)
        {
            var seq = InterlockedIncrement();
            var path = LaunchPathInference.GetPathLabel();
            LogSuppress(seq, area, operation, reason, path);
            CrashContextWriter.RecordSuppress(seq, area, operation, reason, path);
        }

        private static void LogFail(int seq, string area, string operation, Exception ex, string path)
        {
            var type = ex?.GetType().Name ?? "unknown";
            var message = Sanitize(ex?.Message);
            DebugLogger.Test(
                $"[TBG TRACE] seq={seq} area={area} op={operation} stage=fail exception={type} message={message} path={path}",
                showInGame: false);
        }

        private static void Log(int seq, string area, string operation, string stage, string path, long elapsedMs = -1)
        {
            if (stage == "ok" && elapsedMs >= 0)
            {
                DebugLogger.Test(
                    $"[TBG TRACE] seq={seq} area={area} op={operation} stage=ok elapsedMs={elapsedMs} path={path}",
                    showInGame: false);
                return;
            }

            DebugLogger.Test(
                $"[TBG TRACE] seq={seq} area={area} op={operation} stage={stage} path={path}",
                showInGame: false);
        }

        private static void LogDefer(int seq, string area, string operation, string reason, string path)
        {
            DebugLogger.Test(
                $"[TBG TRACE] seq={seq} area={area} op={operation} stage=defer reason={Sanitize(reason)} path={path}",
                showInGame: false);
        }

        private static void LogSuppress(int seq, string area, string operation, string reason, string path)
        {
            DebugLogger.Test(
                $"[TBG TRACE] seq={seq} area={area} op={operation} stage=suppress reason={Sanitize(reason)} path={path}",
                showInGame: false);
        }

        private static int InterlockedIncrement()
        {
            return System.Threading.Interlocked.Increment(ref _sequence);
        }

        private static string Sanitize(string message)
        {
            if (string.IsNullOrEmpty(message))
            {
                return "";
            }

            return message.Replace("\r", " ").Replace("\n", " ").Replace("\"", "'");
        }
    }
}
