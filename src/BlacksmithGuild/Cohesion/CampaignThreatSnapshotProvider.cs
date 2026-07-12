using System;
using System.Collections.Generic;
using System.Diagnostics;
using BlacksmithGuild.DevTools;
using TaleWorlds.CampaignSystem.Party;
using TaleWorlds.Library;

namespace BlacksmithGuild.Cohesion
{
    public sealed class CampaignThreatPartySnapshot
    {
        public string PartyId { get; set; }
        public string PartyName { get; set; }
        public float PositionX { get; set; }
        public float PositionY { get; set; }
        public int Strength { get; set; }
        public float Distance { get; set; }
    }

    public sealed class CampaignThreatSnapshot
    {
        public bool ScanSucceeded { get; set; }
        public string ScanFailure { get; set; }
        public string ProtectedPartyId { get; set; }
        public float ProtectedPositionX { get; set; }
        public float ProtectedPositionY { get; set; }
        public int ProtectedStrength { get; set; }
        public float CapturedMaximumDistance { get; set; }
        public int EnumerationPasses { get; set; }
        public int PartiesEnumerated { get; set; }
        public string CapturedAtUtc { get; set; }
        public long Generation { get; set; }
        public List<CampaignThreatPartySnapshot> Hostiles { get; set; } = new List<CampaignThreatPartySnapshot>();
    }

    /// <summary>
    /// One immutable hostile enumeration shared by travel, trade, cohesion, and future escort workers.
    /// A short monotonic cache prevents each engine from independently scanning MobileParty.All.
    /// </summary>
    public static class CampaignThreatSnapshotProvider
    {
        private const int CacheMilliseconds = 500;
        private const float PositionReuseDistance = 0.25f;
        private static readonly object Sync = new object();
        private static CampaignThreatSnapshot _cached;
        private static long _capturedTimestamp;
        private static long _generation;

        public static CampaignThreatSnapshot Capture(MobileParty protectedParty, float maximumDistance)
        {
            maximumDistance = Math.Max(1f, maximumDistance);
            if (protectedParty == null)
            {
                return Unavailable("protected party unavailable", maximumDistance);
            }

            Vec2 protectedPosition;
            try
            {
                protectedPosition = protectedParty.GetPosition2D;
            }
            catch (Exception ex)
            {
                return Unavailable("protected party position failed: " + ex.GetType().Name, maximumDistance);
            }

            var now = Stopwatch.GetTimestamp();
            lock (Sync)
            {
                if (_cached != null
                    && _cached.ScanSucceeded
                    && _cached.CapturedMaximumDistance >= maximumDistance
                    && string.Equals(_cached.ProtectedPartyId, protectedParty.StringId, StringComparison.Ordinal)
                    && ElapsedMilliseconds(_capturedTimestamp, now) <= CacheMilliseconds
                    && Distance(
                        protectedPosition.x,
                        protectedPosition.y,
                        _cached.ProtectedPositionX,
                        _cached.ProtectedPositionY) <= PositionReuseDistance)
                {
                    return _cached;
                }
            }

            var snapshot = Build(protectedParty, protectedPosition, maximumDistance);
            lock (Sync)
            {
                snapshot.Generation = ++_generation;
                _cached = snapshot;
                _capturedTimestamp = now;
                return _cached;
            }
        }

        public static void ResetForNewCampaign()
        {
            lock (Sync)
            {
                _cached = null;
                _capturedTimestamp = 0;
                _generation = 0;
            }
        }

        private static CampaignThreatSnapshot Build(MobileParty protectedParty, Vec2 position, float maximumDistance)
        {
            if (protectedParty.MapFaction == null)
            {
                return Unavailable("protected party faction unavailable", maximumDistance);
            }

            List<MobileParty> parties;
            try
            {
                parties = new List<MobileParty>(MobileParty.All);
            }
            catch (Exception ex)
            {
                return Unavailable("mobile party enumeration failed: " + ex.GetType().Name, maximumDistance);
            }

            var snapshot = new CampaignThreatSnapshot
            {
                ScanSucceeded = true,
                ProtectedPartyId = protectedParty.StringId,
                ProtectedPositionX = position.x,
                ProtectedPositionY = position.y,
                ProtectedStrength = CampaignMapMovementHelper.PartyStrength(protectedParty),
                CapturedMaximumDistance = maximumDistance,
                EnumerationPasses = 1,
                PartiesEnumerated = parties.Count,
                CapturedAtUtc = DateTime.UtcNow.ToString("o")
            };

            foreach (var party in parties)
            {
                try
                {
                    if (party == null || party == protectedParty || party.MapFaction == null
                        || !protectedParty.MapFaction.IsAtWarWith(party.MapFaction))
                    {
                        continue;
                    }

                    var partyPosition = party.GetPosition2D;
                    var distance = Distance(position.x, position.y, partyPosition.x, partyPosition.y);
                    if (distance > maximumDistance)
                    {
                        continue;
                    }

                    snapshot.Hostiles.Add(new CampaignThreatPartySnapshot
                    {
                        PartyId = party.StringId ?? party.Name?.ToString() ?? "unknown",
                        PartyName = party.Name?.ToString() ?? party.StringId ?? "unknown",
                        PositionX = partyPosition.x,
                        PositionY = partyPosition.y,
                        Strength = CampaignMapMovementHelper.PartyStrength(party),
                        Distance = distance
                    });
                }
                catch
                {
                    // A transient spawning/despawning party is omitted from this generation.
                }
            }

            return snapshot;
        }

        private static CampaignThreatSnapshot Unavailable(string reason, float maximumDistance)
        {
            return new CampaignThreatSnapshot
            {
                ScanSucceeded = false,
                ScanFailure = reason,
                CapturedMaximumDistance = maximumDistance,
                EnumerationPasses = 1,
                CapturedAtUtc = DateTime.UtcNow.ToString("o")
            };
        }

        private static double ElapsedMilliseconds(long startedAt, long endedAt)
        {
            if (startedAt <= 0 || endedAt < startedAt)
            {
                return double.MaxValue;
            }

            return (endedAt - startedAt) * 1000d / Stopwatch.Frequency;
        }

        private static float Distance(float x1, float y1, float x2, float y2)
        {
            var dx = x1 - x2;
            var dy = y1 - y2;
            return (float)Math.Sqrt((dx * dx) + (dy * dy));
        }
    }
}
