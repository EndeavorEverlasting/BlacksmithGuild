using System;
using System.Collections.Generic;
using TaleWorlds.CampaignSystem.Party;
using TaleWorlds.Library;

namespace BlacksmithGuild.Cohesion
{
    public static class CohesionIntentInference
    {
        public static void Apply(
            CohesionPartySnapshot snapshot,
            MobileParty main,
            Dictionary<string, Vec2> priorSamples)
        {
            if (snapshot == null)
            {
                return;
            }

            if (snapshot.RelationToPlayer == CohesionRelationToPlayer.Hostile)
            {
                snapshot.InferredIntent = CohesionIntent.PotentialThreat;
                snapshot.Confidence = snapshot.DistanceToPlayer <= DevTools.DevToolsConfig.MapTradeAbortHostileRadius
                    ? CohesionConfidence.High
                    : CohesionConfidence.Medium;
                return;
            }

            if (snapshot.RelationToPlayer == CohesionRelationToPlayer.Player)
            {
                snapshot.InferredIntent = CohesionIntent.MovingToObjective;
                snapshot.Confidence = CohesionConfidence.High;
                return;
            }

            var warnings = snapshot.ExtractionWarnings;
            var trend = ReadDistanceTrend(snapshot.PartyId, snapshot.PositionX, snapshot.PositionY, main, priorSamples);

            if (snapshot.PartyType == CohesionPartyType.Army || snapshot.PartyType == CohesionPartyType.LordParty)
            {
                if (snapshot.Strength >= 60 && snapshot.RelationToPlayer != CohesionRelationToPlayer.Hostile)
                {
                    snapshot.InferredIntent = CohesionIntent.ShadowableProtector;
                    snapshot.Confidence = CohesionConfidence.Medium;
                    snapshot.ReasonIfNeeded(warnings, "Large friendly lord/army party");
                    return;
                }
            }

            if (trend == DistanceTrend.Approaching)
            {
                snapshot.InferredIntent = CohesionIntent.MovingTowardPlayer;
                snapshot.Confidence = priorSamples.ContainsKey(snapshot.PartyId)
                    ? CohesionConfidence.Medium
                    : CohesionConfidence.Low;
                if (!priorSamples.ContainsKey(snapshot.PartyId))
                {
                    warnings.Add("No prior position sample; approaching intent is tentative");
                }

                return;
            }

            if (trend == DistanceTrend.Receding)
            {
                snapshot.InferredIntent = CohesionIntent.MovingAwayFromPlayer;
                snapshot.Confidence = priorSamples.ContainsKey(snapshot.PartyId)
                    ? CohesionConfidence.Medium
                    : CohesionConfidence.Low;
                return;
            }

            if (snapshot.RelationToPlayer == CohesionRelationToPlayer.Clan
                || snapshot.RelationToPlayer == CohesionRelationToPlayer.Allied
                || snapshot.RelationToPlayer == CohesionRelationToPlayer.Friendly)
            {
                snapshot.InferredIntent = CohesionIntent.PotentialHelper;
                snapshot.Confidence = CohesionConfidence.Low;
                warnings.Add("Helper intent inferred from relation only");
                return;
            }

            snapshot.InferredIntent = CohesionIntent.Unknown;
            snapshot.Confidence = CohesionConfidence.Unknown;
            warnings.Add("Insufficient movement data for intent inference");
        }

        private enum DistanceTrend
        {
            Unknown,
            Approaching,
            Receding,
            Stable
        }

        private static DistanceTrend ReadDistanceTrend(
            string partyId,
            float x,
            float y,
            MobileParty main,
            Dictionary<string, Vec2> priorSamples)
        {
            if (main == null || string.IsNullOrEmpty(partyId) || priorSamples == null
                || !priorSamples.TryGetValue(partyId, out var prior))
            {
                return DistanceTrend.Unknown;
            }

            var current = new Vec2(x, y);
            var mainPos = main.GetPosition2D;
            var priorDistance = prior.Distance(mainPos);
            var currentDistance = current.Distance(mainPos);
            var delta = priorDistance - currentDistance;
            if (Math.Abs(delta) < 0.5f)
            {
                return DistanceTrend.Stable;
            }

            return delta > 0 ? DistanceTrend.Approaching : DistanceTrend.Receding;
        }

        private static void ReasonIfNeeded(this CohesionPartySnapshot snapshot, List<string> warnings, string note)
        {
            if (snapshot.Confidence == CohesionConfidence.Low || snapshot.Confidence == CohesionConfidence.Unknown)
            {
                warnings.Add(note);
            }
        }
    }
}
