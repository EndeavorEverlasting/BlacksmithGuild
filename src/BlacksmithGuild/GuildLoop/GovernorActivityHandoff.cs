using System;
using BlacksmithGuild.MapTrade;

namespace BlacksmithGuild.GuildLoop
{
    public enum GovernorActivityBranch
    {
        Unknown,
        ObserveOnly,
        Travel,
        Trade,
        Provision,
        HorseAcquisition,
        SmithingPrep,
        TavernScan,
        RecruitCompanion,
        ThreatAvoidance,
        Stop
    }

    public enum GovernorActivityPhase
    {
        Observe,
        Decide,
        Dispatch,
        Execute,
        Verify,
        Block,
        Finalize
    }

    public enum GovernorAuthorityMode
    {
        ObservedOnly,
        Recommended,
        Dictated,
        Blocked,
        Terminal
    }

    public sealed class GovernorActivityHandoff
    {
        public string GeneratedUtc { get; set; }
        public int CycleId { get; set; }
        public string SourceEngine { get; set; }
        public string TargetEngine { get; set; }
        public GovernorActivityBranch Branch { get; set; }
        public GovernorActivityPhase Phase { get; set; }
        public GovernorAuthorityMode Authority { get; set; }
        public string ActionName { get; set; }
        public string ObservationSummary { get; set; }
        public string GateVerdict { get; set; }
        public string ProofRequired { get; set; }
        public string EvidenceFile { get; set; }
        public string NextEngineHint { get; set; }
        public bool IsCheckpoint { get; set; }
        public bool IsTerminal { get; set; }
    }

    public static class GovernorActivityHandoffFactory
    {
        public static GovernorActivityHandoff Observed(
            int cycleId,
            string sourceEngine,
            string targetEngine,
            GovernorActivityBranch branch,
            string actionName,
            string observationSummary,
            string evidenceFile = null)
        {
            return New(
                cycleId,
                sourceEngine,
                targetEngine,
                branch,
                GovernorActivityPhase.Observe,
                GovernorAuthorityMode.ObservedOnly,
                actionName,
                observationSummary,
                "observed",
                "fresh state evidence required before branch selection",
                evidenceFile,
                null,
                isCheckpoint: true,
                isTerminal: false);
        }

        public static GovernorActivityHandoff Dictated(
            int cycleId,
            string sourceEngine,
            string targetEngine,
            GovernorActivityBranch branch,
            string actionName,
            string observationSummary,
            string proofRequired,
            string evidenceFile = null,
            string nextEngineHint = null)
        {
            return New(
                cycleId,
                sourceEngine,
                targetEngine,
                branch,
                GovernorActivityPhase.Dispatch,
                GovernorAuthorityMode.Dictated,
                actionName,
                observationSummary,
                "governor_dispatch",
                proofRequired,
                evidenceFile,
                nextEngineHint,
                isCheckpoint: true,
                isTerminal: false);
        }

        public static GovernorActivityHandoff FromMission(
            int cycleId,
            string sourceEngine,
            MapTradeMission mission,
            string nextEngineHint = null)
        {
            var branch = BranchFromMission(mission);
            var actionName = mission?.MissionType.ToString() ?? "NoMission";
            var target = mission?.TargetSettlementName ?? "none";
            var item = mission?.ItemName ?? "none";
            var proof = ProofForBranch(branch);
            return Dictated(
                cycleId,
                sourceEngine,
                "MapTrade",
                branch,
                actionName,
                $"target={target}; item={item}",
                proof,
                "BlacksmithGuild_MapTradeCert.json",
                nextEngineHint);
        }

        public static GovernorActivityHandoff FromTradeExecution(
            int cycleId,
            string sourceEngine,
            MapTradeExecutionResult execution,
            string detail,
            GovernorActivityBranch branch = GovernorActivityBranch.Trade)
        {
            if (execution == null)
            {
                return Blocked(
                    cycleId,
                    sourceEngine,
                    "MapTrade",
                    branch,
                    "TradeExecution",
                    detail ?? "trade execution did not produce a proven delta",
                    branch == GovernorActivityBranch.HorseAcquisition ? "horse_delta_missing" : "trade_delta_missing",
                    "BlacksmithGuild_MapTradeCert.json");
            }

            return New(
                cycleId,
                sourceEngine,
                "Governor",
                branch,
                GovernorActivityPhase.Verify,
                GovernorAuthorityMode.ObservedOnly,
                branch == GovernorActivityBranch.HorseAcquisition ? "PackAnimalBuyVerified" : "TradeExecutionVerified",
                $"item={execution.ItemName}; goldDelta={execution.GoldDelta}; inventoryBefore={execution.InventoryBefore}; inventoryAfter={execution.InventoryAfter}",
                execution.GoldDelta != 0 && execution.InventoryAfter != execution.InventoryBefore ? "delta_proven" : "delta_missing",
                ProofForBranch(branch),
                branch == GovernorActivityBranch.HorseAcquisition
                    ? "BlacksmithGuild_MapTradePackAnimalProbe.json"
                    : "BlacksmithGuild_TradeIterations.jsonl",
                "select next branch from fresh state",
                isCheckpoint: true,
                isTerminal: false);
        }

        public static GovernorActivityHandoff Blocked(
            int cycleId,
            string sourceEngine,
            string targetEngine,
            GovernorActivityBranch branch,
            string actionName,
            string reason,
            string failureClass,
            string evidenceFile = null)
        {
            return New(
                cycleId,
                sourceEngine,
                targetEngine,
                branch,
                GovernorActivityPhase.Block,
                GovernorAuthorityMode.Blocked,
                actionName,
                reason,
                failureClass,
                ProofForBranch(branch),
                evidenceFile,
                "select alternate safe branch or finalize blocked",
                isCheckpoint: true,
                isTerminal: false);
        }

        public static GovernorActivityHandoff Finalized(
            int cycleId,
            string sourceEngine,
            string verdict,
            string reason)
        {
            return New(
                cycleId,
                sourceEngine,
                "Runner",
                GovernorActivityBranch.Stop,
                GovernorActivityPhase.Finalize,
                GovernorAuthorityMode.Terminal,
                verdict ?? "Finalized",
                reason,
                verdict,
                "terminal reason and summary evidence required exactly once",
                "BlacksmithGuild_AutonomousGuildLoop.json",
                null,
                isCheckpoint: false,
                isTerminal: true);
        }

        public static GovernorActivityBranch BranchFromMission(MapTradeMission mission)
        {
            if (mission == null)
            {
                return GovernorActivityBranch.Unknown;
            }

            switch (mission.MissionType)
            {
                case MapTradeMissionType.BuyPackAnimalForCapacityThenTrade:
                    return GovernorActivityBranch.HorseAcquisition;
                case MapTradeMissionType.BuySmithingMaterialAndKeep:
                case MapTradeMissionType.BuySmithingMaterialThenSellSurplus:
                case MapTradeMissionType.BuyProfitGoodAndSell:
                    return GovernorActivityBranch.Trade;
                case MapTradeMissionType.TravelOnlySafetyCert:
                    return GovernorActivityBranch.Travel;
                case MapTradeMissionType.BlockedNoSafeMission:
                    return GovernorActivityBranch.ObserveOnly;
                default:
                    return GovernorActivityBranch.Unknown;
            }
        }

        public static string ProofForBranch(GovernorActivityBranch branch)
        {
            switch (branch)
            {
                case GovernorActivityBranch.Travel:
                    return "source settlement, target settlement, movement command, arrival checkpoint";
                case GovernorActivityBranch.Trade:
                    return "gold before/after, inventory before/after, non-fake trade iteration row";
                case GovernorActivityBranch.Provision:
                    return "food variety, days remaining, projected weight, buy delta if executed";
                case GovernorActivityBranch.HorseAcquisition:
                    return "capacity buffer before/after, pack-animal classification, gold/inventory delta";
                case GovernorActivityBranch.SmithingPrep:
                    return "material before/after, stamina before/after, safe action or blocked reason";
                case GovernorActivityBranch.TavernScan:
                    return "candidate list, companion capacity, safe gold reserve";
                case GovernorActivityBranch.RecruitCompanion:
                    return "roster before/after, gold before/after, direct injection false";
                case GovernorActivityBranch.ThreatAvoidance:
                    return "scan radius, hostile count, nearest hostile, selected fallback";
                case GovernorActivityBranch.Stop:
                    return "terminal state, reason, final evidence, no next action required";
                default:
                    return "fresh state evidence and explicit governor decision required";
            }
        }

        private static GovernorActivityHandoff New(
            int cycleId,
            string sourceEngine,
            string targetEngine,
            GovernorActivityBranch branch,
            GovernorActivityPhase phase,
            GovernorAuthorityMode authority,
            string actionName,
            string observationSummary,
            string gateVerdict,
            string proofRequired,
            string evidenceFile,
            string nextEngineHint,
            bool isCheckpoint,
            bool isTerminal)
        {
            return new GovernorActivityHandoff
            {
                GeneratedUtc = DateTime.UtcNow.ToString("o"),
                CycleId = cycleId,
                SourceEngine = sourceEngine,
                TargetEngine = targetEngine,
                Branch = branch,
                Phase = phase,
                Authority = authority,
                ActionName = actionName,
                ObservationSummary = observationSummary,
                GateVerdict = gateVerdict,
                ProofRequired = proofRequired,
                EvidenceFile = evidenceFile,
                NextEngineHint = nextEngineHint,
                IsCheckpoint = isCheckpoint,
                IsTerminal = isTerminal
            };
        }
    }
}
