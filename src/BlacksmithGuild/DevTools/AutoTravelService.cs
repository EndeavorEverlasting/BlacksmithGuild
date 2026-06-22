using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using BlacksmithGuild.Forge;
using TaleWorlds.CampaignSystem;
using TaleWorlds.CampaignSystem.Party;
using TaleWorlds.CampaignSystem.Settlements;

namespace BlacksmithGuild.DevTools
{
    public static class AutoTravelService
    {
        public const string ShowAutoTravelChoicesCommand = "ShowAutoTravelChoices";
        public const string AutoTravelToRecommendedCommand = "AutoTravelToRecommended";
        public const string AutoTravelChoice1Command = "AutoTravelChoice1";
        public const string AutoTravelChoice2Command = "AutoTravelChoice2";
        public const string AutoTravelChoice3Command = "AutoTravelChoice3";
        public const string AutoTravelChoice4Command = "AutoTravelChoice4";
        public const string AutoTravelChoice5Command = "AutoTravelChoice5";
        public const string AutoTravelPrefix = "AutoTravel:";

        private const int ChoiceCount = 5;
        private static readonly List<AutoTravelChoice> _choices = new List<AutoTravelChoice>();
        private static string _lastFailReason;
        private static Settlement _activeDestination;

        public static string LastFailReason => _lastFailReason;

        public static void OnCampaignTick()
        {
            if (_activeDestination == null || !GameSessionState.IsCampaignMapReady || MobileParty.MainParty == null)
            {
                return;
            }

            if (MobileParty.MainParty.Position2D.Distance(_activeDestination.Position2D) <= 1.5f)
            {
                var arrived = _activeDestination.Name?.ToString() ?? _activeDestination.StringId;
                _activeDestination = null;
                InGameNotice.Success($"TBG TRAVEL: arrived near {arrived}.");
                return;
            }

            if (TryDetectBlockingHostiles(MobileParty.MainParty, out var hostileDetail))
            {
                TryInvokeHold(MobileParty.MainParty);
                _activeDestination = null;
                _lastFailReason = hostileDetail;
                InGameNotice.Blocked($"TBG TRAVEL paused: {hostileDetail}");
                DebugLogger.Test($"[TBG TRAVEL] paused route monitor: {hostileDetail}", showInGame: false);
            }
        }

        public static DevCommandResult ShowChoices()
        {
            if (!RefreshChoices())
            {
                return DevCommandResult.Failed;
            }

            InGameNotice.Info("TBG TRAVEL choices: type AutoTravelChoice1-5 or AutoTravel:<town>.");
            foreach (var choice in _choices)
            {
                InGameNotice.Info($"{choice.Number}) {choice.Name} — {choice.Reason}");
                DebugLogger.Test($"[TBG TRAVEL] {choice.Number}) {choice.Name} id={choice.StringId} reason={choice.Reason}", showInGame: false);
            }

            return DevCommandResult.Success;
        }

        public static DevCommandResult TravelToRecommended()
        {
            return TravelByChoiceNumber(1);
        }

        public static DevCommandResult TravelByChoiceNumber(int number)
        {
            if (_choices.Count == 0 && !RefreshChoices())
            {
                return DevCommandResult.Failed;
            }

            var choice = _choices.FirstOrDefault(c => c.Number == number);
            if (choice == null)
            {
                _lastFailReason = $"choice {number} is not available; run {ShowAutoTravelChoicesCommand}";
                return DevCommandResult.Failed;
            }

            return StartTravel(choice.Settlement, $"choice {number}");
        }

        public static DevCommandResult TravelByName(string name)
        {
            if (string.IsNullOrWhiteSpace(name))
            {
                _lastFailReason = "destination name was empty";
                return DevCommandResult.Failed;
            }

            var destination = FindSettlement(name.Trim());
            if (destination == null)
            {
                _lastFailReason = $"could not find town/village named '{name}'";
                InGameNotice.Fail($"TBG TRAVEL: {_lastFailReason}.");
                ShowChoices();
                return DevCommandResult.Failed;
            }

            return StartTravel(destination, "name");
        }

        private static bool RefreshChoices()
        {
            _choices.Clear();
            _lastFailReason = null;

            if (!GameSessionState.IsCampaignMapReady || MobileParty.MainParty == null)
            {
                _lastFailReason = GameSessionState.GetCampaignMapBlockDetail();
                return false;
            }

            var main = MobileParty.MainParty;
            var ranked = Settlement.All
                .Where(IsTownOrVillage)
                .Select(s => new { Settlement = s, Score = ScoreSettlement(s, main), Reason = BuildReason(s) })
                .OrderByDescending(x => x.Score)
                .ThenBy(x => x.Settlement.Name?.ToString())
                .Take(ChoiceCount)
                .ToList();

            var number = 1;
            foreach (var item in ranked)
            {
                _choices.Add(new AutoTravelChoice
                {
                    Number = number++,
                    Settlement = item.Settlement,
                    Name = item.Settlement.Name?.ToString() ?? item.Settlement.StringId,
                    StringId = item.Settlement.StringId,
                    Reason = item.Reason
                });
            }

            if (_choices.Count == 0)
            {
                _lastFailReason = "no towns or villages found";
                return false;
            }

            return true;
        }

        private static DevCommandResult StartTravel(Settlement destination, string selector)
        {
            if (!GameSessionState.IsCampaignMapReady || MobileParty.MainParty == null)
            {
                _lastFailReason = GameSessionState.GetCampaignMapBlockDetail();
                return DevCommandResult.Failed;
            }

            if (destination == null)
            {
                _lastFailReason = "destination was not resolved";
                return DevCommandResult.Failed;
            }

            if (TryDetectBlockingHostiles(MobileParty.MainParty, out var hostileDetail))
            {
                _lastFailReason = hostileDetail;
                InGameNotice.Blocked($"TBG TRAVEL blocked: {hostileDetail}");
                return DevCommandResult.Blocked;
            }

            if (!TryInvokeMoveToSettlement(MobileParty.MainParty, destination))
            {
                _lastFailReason = "Bannerlord move-to-settlement API was unavailable";
                return DevCommandResult.Failed;
            }

            var name = destination.Name?.ToString() ?? destination.StringId;
            _activeDestination = destination;
            DebugLogger.Test($"[TBG TRAVEL] auto-travel started to {name} via {selector}; cautious route monitor active.", showInGame: false);
            InGameNotice.Success($"TBG TRAVEL: heading to {name}. Avoid enemies/bandits if they threaten route.");
            return DevCommandResult.Success;
        }

        private static void TryInvokeHold(MobileParty party)
        {
            if (party == null)
            {
                return;
            }

            var method = party.GetType().GetMethod("SetMoveModeHold", BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic, null, Type.EmptyTypes, null);
            method?.Invoke(party, new object[0]);
        }

        private static bool TryInvokeMoveToSettlement(MobileParty party, Settlement destination)
        {
            var methods = new[] { "SetMoveGoToSettlement", "SetMoveGoToSettlementWithShorterPath", "AiSetMoveGoToSettlement" };
            foreach (var name in methods)
            {
                var method = party.GetType().GetMethod(name, BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic, null, new[] { typeof(Settlement) }, null);
                if (method == null) continue;
                method.Invoke(party, new object[] { destination });
                return true;
            }

            return false;
        }

        private static bool TryDetectBlockingHostiles(MobileParty main, out string detail)
        {
            detail = null;
            foreach (var party in MobileParty.All)
            {
                if (party == null || party == main || party.MapFaction == null || main.MapFaction == null ||
                    !party.MapFaction.IsAtWarWith(main.MapFaction))
                {
                    continue;
                }

                var distance = main.Position2D.Distance(party.Position2D);
                var hostileStrength = party.Party == null ? 0 : party.Party.NumberOfAllMembers;
                var mainStrength = main.Party == null ? 0 : main.Party.NumberOfAllMembers;
                if (distance <= 6f && hostileStrength >= mainStrength)
                {
                    detail = $"nearby hostile {party.Name} is too close/strong; wait or move manually";
                    return true;
                }
            }

            return false;
        }

        private static Settlement FindSettlement(string name)
        {
            var normalized = Normalize(name);
            return Settlement.All.Where(IsTownOrVillage).FirstOrDefault(s =>
                string.Equals(Normalize(s.Name?.ToString()), normalized, StringComparison.OrdinalIgnoreCase) ||
                string.Equals(Normalize(s.StringId), normalized, StringComparison.OrdinalIgnoreCase) ||
                Normalize(s.Name?.ToString()).Contains(normalized));
        }

        private static bool IsTownOrVillage(Settlement settlement)
        {
            return settlement != null && (settlement.IsTown || settlement.IsVillage);
        }

        private static float ScoreSettlement(Settlement settlement, MobileParty main)
        {
            var distancePenalty = main == null ? 0f : main.Position2D.Distance(settlement.Position2D) * 2f;
            var townBonus = settlement.IsTown ? 100f : 35f;
            var forgeBonus = ForgeRecommendationService.Summary.HasRankings ? 25f : 0f;
            return townBonus + forgeBonus - distancePenalty;
        }

        private static string BuildReason(Settlement settlement)
        {
            if (settlement.IsTown && ForgeRecommendationService.Summary.HasRankings)
            {
                return "trade/forge engine-friendly town";
            }

            return settlement.IsTown ? "nearby town market" : "nearby village stop";
        }

        private static string Normalize(string value)
        {
            return (value ?? string.Empty).Trim().Replace(" ", string.Empty).Replace("-", string.Empty).ToLowerInvariant();
        }

        private sealed class AutoTravelChoice
        {
            public int Number { get; set; }
            public Settlement Settlement { get; set; }
            public string Name { get; set; }
            public string StringId { get; set; }
            public string Reason { get; set; }
        }
    }
}
