using System;
using System.Collections.Generic;
using System.Reflection;
using BlacksmithGuild.DevTools;
using TaleWorlds.CampaignSystem;
using TaleWorlds.CampaignSystem.Party;
using TaleWorlds.CampaignSystem.Settlements;
using TaleWorlds.Library;

namespace BlacksmithGuild.Cohesion
{
    public static class CohesionPartyScanner
    {
        private static readonly Dictionary<string, Vec2> _positionSamples = new Dictionary<string, Vec2>();

        public static void ResetForNewCampaign()
        {
            _positionSamples.Clear();
        }

        public static List<CohesionPartySnapshot> Scan(float radius, MobileParty main)
        {
            var results = new List<CohesionPartySnapshot>();
            if (!IsPartyReadable(main))
            {
                return results;
            }

            // Snapshot the collection first: MobileParty.All can mutate mid-enumeration while the
            // campaign clock is running (parties spawn/despawn), which can corrupt the iterator.
            List<MobileParty> parties;
            try
            {
                parties = new List<MobileParty>(MobileParty.All);
            }
            catch
            {
                return results;
            }

            foreach (var party in parties)
            {
                // Skip transient parties that are unsafe to dereference during active simulation
                // (mid-spawn / being torn down). This is the crash window exposed once travel
                // resumes the campaign clock; touching such a party can trigger a native AV.
                if (!IsPartyReadable(party))
                {
                    continue;
                }

                var distance = CampaignMapMovementHelper.Distance(main, party);
                if (party != main && distance > radius)
                {
                    continue;
                }

                results.Add(BuildSnapshot(party, main, distance));
            }

            return results;
        }

        private static bool IsPartyReadable(MobileParty party)
        {
            if (party == null)
            {
                return false;
            }

            try
            {
                return party.IsActive && party.Party != null;
            }
            catch
            {
                return false;
            }
        }

        public static CohesionPartySnapshot BuildSnapshot(MobileParty party, MobileParty main, float distanceToPlayer)
        {
            var pos = party.GetPosition2D;
            var snapshot = new CohesionPartySnapshot
            {
                PartyId = party.StringId ?? party.Name?.ToString() ?? "unknown",
                Name = party.Name?.ToString() ?? party.StringId,
                Faction = party.MapFaction?.Name?.ToString() ?? "none",
                RelationToPlayer = CohesionPartyClassifier.ClassifyRelation(party, main),
                PartyType = CohesionPartyClassifier.ClassifyType(party),
                PositionX = pos.x,
                PositionY = pos.y,
                Speed = ReadSpeed(party),
                Strength = CampaignMapMovementHelper.PartyStrength(party),
                TroopCount = party.Party?.NumberOfRegularMembers ?? 0,
                WoundedCount = party.Party?.NumberOfWoundedTotalMembers ?? 0,
                DistanceToPlayer = distanceToPlayer,
                ControllableByPlayer = party == main || IsClanPartyControllable(party, main),
                MovementApiAvailable = party == main || IsClanPartyControllable(party, main),
                Confidence = CohesionConfidence.Medium
            };

            ExtractTargets(party, snapshot);
            CohesionIntentInference.Apply(snapshot, main, _positionSamples);
            RecordSample(snapshot.PartyId, pos);
            return snapshot;
        }

        public static Settlement FindNearestSafeTown(MobileParty main, float maxDistance = 50f)
        {
            Settlement best = null;
            var bestDistance = float.MaxValue;
            foreach (var settlement in Settlement.All)
            {
                if (settlement == null || !settlement.IsTown)
                {
                    continue;
                }

                var distance = CampaignMapMovementHelper.Distance(main, settlement);
                if (distance > maxDistance || distance >= bestDistance)
                {
                    continue;
                }

                best = settlement;
                bestDistance = distance;
            }

            return best;
        }

        public static List<CohesionPartySnapshot> FilterHostiles(IEnumerable<CohesionPartySnapshot> snapshots)
        {
            var list = new List<CohesionPartySnapshot>();
            foreach (var snapshot in snapshots)
            {
                if (snapshot.RelationToPlayer == CohesionRelationToPlayer.Hostile)
                {
                    list.Add(snapshot);
                }
            }

            return list;
        }

        public static List<CohesionPartySnapshot> FilterHelpers(IEnumerable<CohesionPartySnapshot> snapshots)
        {
            var list = new List<CohesionPartySnapshot>();
            foreach (var snapshot in snapshots)
            {
                if (snapshot.RelationToPlayer == CohesionRelationToPlayer.Player)
                {
                    continue;
                }

                if (snapshot.RelationToPlayer == CohesionRelationToPlayer.Clan
                    || snapshot.RelationToPlayer == CohesionRelationToPlayer.Allied
                    || snapshot.RelationToPlayer == CohesionRelationToPlayer.Friendly
                    || snapshot.RelationToPlayer == CohesionRelationToPlayer.NeutralProtector
                    || snapshot.InferredIntent == CohesionIntent.ShadowableProtector
                    || snapshot.InferredIntent == CohesionIntent.PotentialHelper)
                {
                    list.Add(snapshot);
                }
            }

            return list;
        }

        public static int ClusterStrength(IEnumerable<CohesionPartySnapshot> hostiles, float clusterRadius = 8f)
        {
            var total = 0;
            foreach (var hostile in hostiles)
            {
                total += hostile.Strength;
            }

            return total;
        }

        private static void RecordSample(string partyId, Vec2 pos)
        {
            if (string.IsNullOrEmpty(partyId))
            {
                return;
            }

            _positionSamples[partyId] = pos;
        }

        private static float ReadSpeed(MobileParty party)
        {
            try
            {
                return party.Speed;
            }
            catch
            {
                return 1f;
            }
        }

        private static bool IsClanPartyControllable(MobileParty party, MobileParty main)
        {
            if (!DevToolsConfig.CohesionAllowClanPartyCommands)
            {
                return false;
            }

            if (party.ActualClan == null || main.ActualClan == null || party.ActualClan != main.ActualClan)
            {
                return false;
            }

            return party != main && party.LeaderHero != Hero.MainHero;
        }

        private static void ExtractTargets(MobileParty party, CohesionPartySnapshot snapshot)
        {
            try
            {
                if (party.TargetSettlement != null)
                {
                    snapshot.TargetSettlementId = party.TargetSettlement.StringId;
                }
            }
            catch
            {
                snapshot.ExtractionWarnings.Add("TargetSettlement unavailable");
            }

            try
            {
                var targetParty = TryReadTargetParty(party);
                if (targetParty != null)
                {
                    snapshot.TargetPartyId = targetParty.StringId;
                }
            }
            catch
            {
                snapshot.ExtractionWarnings.Add("TargetParty unavailable");
            }

            try
            {
                snapshot.CurrentBehavior = party.DefaultBehavior.ToString();
            }
            catch
            {
                snapshot.ExtractionWarnings.Add("DefaultBehavior unavailable");
            }
        }

        private static MobileParty TryReadTargetParty(MobileParty party)
        {
            var property = party.GetType().GetProperty(
                "TargetParty",
                BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic);
            return property?.GetValue(party) as MobileParty;
        }
    }
}
