using BlacksmithGuild.DevTools;

namespace BlacksmithGuild.Cohesion
{
    public static class CohesionDoctrine
    {
        public const string SetCohesionDoctrineTradeForgeCommand = "SetCohesionDoctrineTradeForge";
        public const string SetCohesionDoctrineReliefCommand = "SetCohesionDoctrineRelief";
        public const string SetCohesionDoctrineEscortCommand = "SetCohesionDoctrineEscort";
        public const string SetCohesionDoctrineBanditSuppressionCommand = "SetCohesionDoctrineBanditSuppression";

        private static CohesionDoctrineKind _active = CohesionDoctrineKind.TradeForge;

        public static CohesionDoctrineKind Active => _active;

        public static string GetLabel() => _active.ToString();

        public static bool SetDoctrine(CohesionDoctrineKind kind)
        {
            _active = kind;
            DevToolsConfig.CohesionDefaultDoctrine = kind;
            InGameNotice.Info($"TBG COHESION: doctrine set to {kind}.");
            DebugLogger.Test($"[TBG COHESION] doctrine set to {kind}", showInGame: false);
            return true;
        }

        public static CohesionObjective BuildDefaultObjective()
        {
            return CohesionEngine.BuildObjectiveFromDoctrine(_active);
        }
    }
}
