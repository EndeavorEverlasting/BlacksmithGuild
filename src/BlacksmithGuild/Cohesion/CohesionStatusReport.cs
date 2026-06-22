using System;
using BlacksmithGuild.DevTools;

namespace BlacksmithGuild.Cohesion
{
    public static class CohesionStatusReport
    {
        public static string CurrentState =>
            CohesionExecutionDriver.IsRunning
                ? CohesionExecutionDriver.ActiveReport?.State.ToString() ?? "Running"
                : CohesionExecutionDriver.ActiveReport?.State.ToString() ?? "Idle";

        public static string CurrentVerdict =>
            CohesionExecutionDriver.ActiveReport?.Verdict
            ?? CohesionEngine.LastReport?.Verdict
            ?? "NoReport";

        public static bool IsTerminal =>
            !CohesionExecutionDriver.IsRunning
            && (CohesionExecutionDriver.ActiveReport == null
                || CohesionExecutionDriver.ActiveReport.State == CohesionExecutionState.Complete
                || CohesionExecutionDriver.ActiveReport.State == CohesionExecutionState.Blocked
                || CohesionExecutionDriver.ActiveReport.State == CohesionExecutionState.Aborted
                || CohesionExecutionDriver.ActiveReport.State == CohesionExecutionState.Failed);

        public static string GetSummaryLine()
        {
            if (CohesionExecutionDriver.IsRunning)
            {
                return $"cohesion move running: {CurrentState}";
            }

            var last = CohesionEngine.LastReport;
            if (last?.SelectedOpportunity != null)
            {
                return $"last plan: {last.SelectedOpportunity.RecommendedAction} score={last.SelectedOpportunity.Score:0.#}";
            }

            return $"cohesion: {CurrentVerdict}";
        }

        public static bool ShowStatusNow()
        {
            InGameNotice.Info($"TBG COHESION STATUS: {GetSummaryLine()}");
            if (CohesionEngine.LastReport != null)
            {
                CohesionJsonWriter.WriteOpportunities(CohesionEngine.LastReport);
            }

            if (CohesionExecutionDriver.ActiveReport != null)
            {
                CohesionJsonWriter.WriteMove(CohesionExecutionDriver.ActiveReport);
            }

            return true;
        }
    }
}
