using System;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using BlacksmithGuild.DevTools;
using TaleWorlds.CampaignSystem;
using TaleWorlds.CampaignSystem.Party;
using TaleWorlds.CampaignSystem.Settlements;
using TaleWorlds.Library;

namespace BlacksmithGuild.DevTools.Assistive
{
    public static class MovementProofLedgerService
    {
        private const string FileName = "BlacksmithGuild_MovementProof.json";
        private const double DistanceEpsilon = 0.01d;
        private static readonly string LedgerPath = Path.Combine(BasePath.Name, FileName);

        public static MovementProofLedger Begin(
            AssistiveTravelExecutionResult result,
            Settlement target,
            string source)
        {
            var ledger = new MovementProofLedger
            {
                AttemptId = Guid.NewGuid().ToString("N"),
                CommandName = "AssistiveLeaveTownAndTravel",
                Source = string.IsNullOrWhiteSpace(source) ? "unknown" : source,
                CommandAckObserved = result?.CommandAccepted == true,
                ExecuteRequested = result?.ExecuteRequested == true,
                ExecuteAllowed = result?.ExecuteAllowed == true,
                TravelApiCallSucceeded = result?.TravelApiCallSucceeded == true,
                TargetSettlement = target?.Name?.ToString() ?? result?.TargetSettlement,
                TargetSettlementId = target?.StringId ?? result?.TargetSettlementId,
                PartyMovedDistance = result?.PartyMovedDistance ?? 0d
            };

            if (result != null)
            {
                result.MovementProof = ledger;
                result.MovementProofClassification = MovementProofClassification.Unknown.ToString();
                result.MovementProofReason = null;
                result.MovementMetricDisagreement = false;
                result.MovementCheckpointObserved = false;
            }

            return ledger;
        }

        public static MovementProofSample CaptureSample(
            MovementProofLedger ledger,
            string phase,
            string reason = null)
        {
            if (ledger == null)
            {
                return null;
            }

            var party = MobileParty.MainParty;
            Settlement currentSettlement = null;
            Settlement nearestSettlement = null;
            double? posX = null;
            double? posY = null;
            double? distanceFromStart = null;
            double? distanceToTarget = null;

            try
            {
                currentSettlement = GameSessionState.ResolveCurrentSettlement();
            }
            catch
            {
            }

            if (party != null)
            {
                try
                {
                    var pos = party.GetPosition2D;
                    posX = pos.x;
                    posY = pos.y;
                    nearestSettlement = ResolveNearestSettlement(pos);

                    if (ledger.Samples.Count > 0)
                    {
                        var first = ledger.Samples[0];
                        if (first.PositionX.HasValue && first.PositionY.HasValue)
                        {
                            var start = new Vec2((float)first.PositionX.Value, (float)first.PositionY.Value);
                            distanceFromStart = pos.Distance(start);
                        }
                    }

                    var target = ResolveTargetSettlement(ledger);
                    if (target != null)
                    {
                        distanceToTarget = pos.Distance(target.GetPosition2D);
                    }
                }
                catch
                {
                }
            }

            var sample = new MovementProofSample
            {
                Phase = string.IsNullOrWhiteSpace(phase) ? "unknown" : phase,
                Reason = reason,
                TimestampUtc = DateTime.UtcNow.ToString("o"),
                PositionX = posX,
                PositionY = posY,
                CurrentSettlement = currentSettlement?.Name?.ToString() ?? GameSessionState.CurrentSettlementName,
                CurrentSettlementId = currentSettlement?.StringId ?? GameSessionState.CurrentSettlementStringId,
                NearestSettlement = nearestSettlement?.Name?.ToString(),
                NearestSettlementId = nearestSettlement?.StringId,
                TargetSettlement = ledger.TargetSettlement,
                TargetSettlementId = ledger.TargetSettlementId,
                DistanceFromStart = distanceFromStart,
                DistanceToTarget = distanceToTarget,
                MapTimeText = ReadMapTimeText(),
                CampaignClockRunning = CampaignClockResumeHelper.IsClockRunning(),
                MovementIntentSet = ledger.ExecuteRequested && ledger.ExecuteAllowed && ledger.TravelApiCallSucceeded
            };

            ledger.Samples.Add(sample);
            return sample;
        }

        public static MovementProofDeltas ComputeDeltas(MovementProofLedger ledger)
        {
            var deltas = ledger?.Deltas ?? new MovementProofDeltas();
            if (ledger == null || ledger.Samples == null || ledger.Samples.Count == 0)
            {
                return deltas;
            }

            var samples = ledger.Samples;
            var first = samples.FirstOrDefault();
            var last = samples.LastOrDefault();
            deltas.StartDistanceToTarget = first?.DistanceToTarget;
            deltas.LastDistanceToTarget = last?.DistanceToTarget;
            deltas.MaxDistanceFromStart = samples
                .Where(sample => sample?.DistanceFromStart.HasValue == true)
                .Select(sample => sample.DistanceFromStart.Value)
                .DefaultIfEmpty(0d)
                .Max();

            deltas.PositionChanged = samples.Any(sample =>
                sample?.PositionX.HasValue == true && sample.PositionY.HasValue == true &&
                first?.PositionX.HasValue == true && first.PositionY.HasValue == true &&
                (Math.Abs(sample.PositionX.Value - first.PositionX.Value) > DistanceEpsilon ||
                 Math.Abs(sample.PositionY.Value - first.PositionY.Value) > DistanceEpsilon));

            deltas.CurrentSettlementChanged = samples.Any(sample => !Same(sample?.CurrentSettlementId, first?.CurrentSettlementId));
            deltas.NearestSettlementChanged = samples.Any(sample => !Same(sample?.NearestSettlementId, first?.NearestSettlementId));
            deltas.TargetChanged = samples.Any(sample => !Same(sample?.TargetSettlementId, first?.TargetSettlementId));
            deltas.DistanceToTargetChanged = HasNumericChange(samples.Select(sample => sample?.DistanceToTarget).ToArray());
            deltas.MapTimeAdvanced = samples
                .Where(sample => !string.IsNullOrWhiteSpace(sample?.MapTimeText))
                .Select(sample => sample.MapTimeText)
                .Distinct(StringComparer.Ordinal)
                .Count() > 1;
            deltas.PartyMovedDistanceChanged = ledger.PartyMovedDistance > 0d;
            ledger.Deltas = deltas;
            return deltas;
        }

        public static MovementProofClassification Classify(
            MovementProofLedger ledger,
            bool foregroundInterrupted = false,
            bool fairWindowElapsed = false)
        {
            if (ledger == null)
            {
                return MovementProofClassification.Unknown;
            }

            var deltas = ComputeDeltas(ledger);
            var checkpointObserved = HasCheckpointObserved(ledger, deltas);
            var distanceObserved = ledger.PartyMovedDistance > 0d;
            var commandArmed = ledger.CommandAckObserved && ledger.ExecuteRequested && ledger.ExecuteAllowed;

            if (checkpointObserved && !distanceObserved)
            {
                ledger.Classification = MovementProofClassification.MovementMetricDisagreement;
                ledger.ClassificationReason = "durable_checkpoint_observed_with_zero_partyMovedDistance";
                ledger.PartyMovedDistanceReliable = false;
                return ledger.Classification;
            }

            if (checkpointObserved)
            {
                ledger.Classification = MovementProofClassification.MovementCheckpointObserved;
                ledger.ClassificationReason = "durable_checkpoint_observed";
                ledger.PartyMovedDistanceReliable = true;
                return ledger.Classification;
            }

            if (distanceObserved)
            {
                ledger.Classification = MovementProofClassification.MovementDistanceObserved;
                ledger.ClassificationReason = "partyMovedDistance_gt_zero";
                ledger.PartyMovedDistanceReliable = true;
                return ledger.Classification;
            }

            if (foregroundInterrupted && commandArmed)
            {
                ledger.Classification = MovementProofClassification.ForegroundInterruptionPreventedObservation;
                ledger.ClassificationReason = "foreground_interruption_prevented_observation";
                ledger.PartyMovedDistanceReliable = true;
                return ledger.Classification;
            }

            if (fairWindowElapsed && commandArmed)
            {
                ledger.Classification = MovementProofClassification.MovementNotObservedAfterFairWindow;
                ledger.ClassificationReason = "fair_window_elapsed_without_durable_movement";
                ledger.PartyMovedDistanceReliable = true;
                return ledger.Classification;
            }

            if (commandArmed || ledger.TravelApiCallSucceeded)
            {
                ledger.Classification = MovementProofClassification.MovementCommandAckWithoutDurableEvidence;
                ledger.ClassificationReason = "command_ack_without_durable_movement";
                ledger.PartyMovedDistanceReliable = true;
                return ledger.Classification;
            }

            ledger.Classification = MovementProofClassification.MovementObservationIndeterminate;
            ledger.ClassificationReason = "movement_observation_incomplete";
            ledger.PartyMovedDistanceReliable = true;
            return ledger.Classification;
        }

        public static void Write(MovementProofLedger ledger)
        {
            if (ledger == null)
            {
                return;
            }

            try
            {
                File.WriteAllText(LedgerPath, Serialize(ledger), Encoding.UTF8);
            }
            catch (Exception ex)
            {
                DebugLogger.Test($"[TBG ASSIST] movement proof write failed: {ex.Message}", showInGame: false);
            }
        }

        private static bool HasCheckpointObserved(MovementProofLedger ledger, MovementProofDeltas deltas)
        {
            var last = ledger.Samples.LastOrDefault();
            var mapTimeAdvanceWithTravel = deltas.MapTimeAdvanced && last != null && (last.CampaignClockRunning || last.MovementIntentSet);
            return deltas.PositionChanged
                || deltas.CurrentSettlementChanged
                || deltas.NearestSettlementChanged
                || deltas.DistanceToTargetChanged
                || mapTimeAdvanceWithTravel
                || HasArrived(ledger);
        }

        private static bool HasArrived(MovementProofLedger ledger)
        {
            var last = ledger?.Samples?.LastOrDefault();
            if (last == null)
            {
                return false;
            }

            if (!string.IsNullOrWhiteSpace(last.TargetSettlementId) && Same(last.TargetSettlementId, last.CurrentSettlementId))
            {
                return true;
            }

            return last.DistanceToTarget.HasValue && last.DistanceToTarget.Value <= 1.5d;
        }

        private static Settlement ResolveTargetSettlement(MovementProofLedger ledger)
        {
            if (ledger == null || string.IsNullOrWhiteSpace(ledger.TargetSettlementId))
            {
                return null;
            }

            try
            {
                return Settlement.All?.FirstOrDefault(settlement => Same(settlement?.StringId, ledger.TargetSettlementId));
            }
            catch
            {
                return null;
            }
        }

        private static Settlement ResolveNearestSettlement(Vec2 position)
        {
            try
            {
                Settlement best = null;
                var bestDistance = float.MaxValue;
                foreach (var settlement in Settlement.All)
                {
                    if (settlement == null)
                    {
                        continue;
                    }

                    var distance = position.Distance(settlement.GetPosition2D);
                    if (distance < bestDistance)
                    {
                        bestDistance = distance;
                        best = settlement;
                    }
                }

                return best;
            }
            catch
            {
                return null;
            }
        }

        private static string ReadMapTimeText()
        {
            try
            {
                if (Campaign.Current == null)
                {
                    return null;
                }

                return CampaignTime.Now.ToDays.ToString("0.###", CultureInfo.InvariantCulture);
            }
            catch
            {
                return null;
            }
        }

        private static bool HasNumericChange(double?[] values)
        {
            var present = values.Where(value => value.HasValue).Select(value => value.Value).ToArray();
            if (present.Length <= 1)
            {
                return false;
            }

            var first = present[0];
            return present.Any(value => Math.Abs(value - first) > DistanceEpsilon);
        }

        private static bool Same(string left, string right)
        {
            if (string.IsNullOrWhiteSpace(left) && string.IsNullOrWhiteSpace(right))
            {
                return true;
            }

            return string.Equals(left ?? string.Empty, right ?? string.Empty, StringComparison.OrdinalIgnoreCase);
        }

        private static string Serialize(MovementProofLedger ledger)
        {
            var sb = new StringBuilder();
            sb.AppendLine("{");
            sb.AppendLine($"  \"schemaVersion\": {ledger.SchemaVersion},");
            sb.AppendLine($"  \"attemptId\": {JsonString(ledger.AttemptId)},");
            sb.AppendLine($"  \"commandName\": {JsonString(ledger.CommandName)},");
            sb.AppendLine($"  \"source\": {JsonString(ledger.Source)},");
            sb.AppendLine($"  \"commandAckObserved\": {JsonBool(ledger.CommandAckObserved)},");
            sb.AppendLine($"  \"executeRequested\": {JsonBool(ledger.ExecuteRequested)},");
            sb.AppendLine($"  \"executeAllowed\": {JsonBool(ledger.ExecuteAllowed)},");
            sb.AppendLine($"  \"travelApiCallSucceeded\": {JsonBool(ledger.TravelApiCallSucceeded)},");
            sb.AppendLine($"  \"targetSettlement\": {JsonString(ledger.TargetSettlement)},");
            sb.AppendLine($"  \"targetSettlementId\": {JsonString(ledger.TargetSettlementId)},");
            sb.AppendLine("  \"samples\": [");
            for (var i = 0; i < ledger.Samples.Count; i++)
            {
                AppendSample(sb, ledger.Samples[i], i < ledger.Samples.Count - 1);
            }

            sb.AppendLine("  ],");
            AppendDeltas(sb, ledger.Deltas);
            sb.AppendLine($"  \"classification\": {JsonString(ledger.Classification.ToString())},");
            sb.AppendLine($"  \"classificationReason\": {JsonString(ledger.ClassificationReason)},");
            sb.AppendLine($"  \"partyMovedDistanceReliable\": {JsonBool(ledger.PartyMovedDistanceReliable)},");
            sb.AppendLine($"  \"partyMovedDistance\": {JsonDouble(ledger.PartyMovedDistance)}");
            sb.AppendLine("}");
            return sb.ToString();
        }

        private static void AppendSample(StringBuilder sb, MovementProofSample sample, bool trailingComma)
        {
            sb.AppendLine("    {");
            sb.AppendLine($"      \"phase\": {JsonString(sample.Phase)},");
            sb.AppendLine($"      \"reason\": {JsonString(sample.Reason)},");
            sb.AppendLine($"      \"timestampUtc\": {JsonString(sample.TimestampUtc)},");
            sb.AppendLine($"      \"positionX\": {JsonNullableDouble(sample.PositionX)},");
            sb.AppendLine($"      \"positionY\": {JsonNullableDouble(sample.PositionY)},");
            sb.AppendLine($"      \"currentSettlement\": {JsonString(sample.CurrentSettlement)},");
            sb.AppendLine($"      \"currentSettlementId\": {JsonString(sample.CurrentSettlementId)},");
            sb.AppendLine($"      \"nearestSettlement\": {JsonString(sample.NearestSettlement)},");
            sb.AppendLine($"      \"nearestSettlementId\": {JsonString(sample.NearestSettlementId)},");
            sb.AppendLine($"      \"targetSettlement\": {JsonString(sample.TargetSettlement)},");
            sb.AppendLine($"      \"targetSettlementId\": {JsonString(sample.TargetSettlementId)},");
            sb.AppendLine($"      \"distanceFromStart\": {JsonNullableDouble(sample.DistanceFromStart)},");
            sb.AppendLine($"      \"distanceToTarget\": {JsonNullableDouble(sample.DistanceToTarget)},");
            sb.AppendLine($"      \"mapTimeText\": {JsonString(sample.MapTimeText)},");
            sb.AppendLine($"      \"campaignClockRunning\": {JsonBool(sample.CampaignClockRunning)},");
            sb.AppendLine($"      \"movementIntentSet\": {JsonBool(sample.MovementIntentSet)}");
            sb.Append("    }");
            sb.AppendLine(trailingComma ? "," : string.Empty);
        }

        private static void AppendDeltas(StringBuilder sb, MovementProofDeltas deltas)
        {
            deltas = deltas ?? new MovementProofDeltas();
            sb.AppendLine("  \"deltas\": {");
            sb.AppendLine($"    \"positionChanged\": {JsonBool(deltas.PositionChanged)},");
            sb.AppendLine($"    \"currentSettlementChanged\": {JsonBool(deltas.CurrentSettlementChanged)},");
            sb.AppendLine($"    \"nearestSettlementChanged\": {JsonBool(deltas.NearestSettlementChanged)},");
            sb.AppendLine($"    \"targetChanged\": {JsonBool(deltas.TargetChanged)},");
            sb.AppendLine($"    \"distanceToTargetChanged\": {JsonBool(deltas.DistanceToTargetChanged)},");
            sb.AppendLine($"    \"mapTimeAdvanced\": {JsonBool(deltas.MapTimeAdvanced)},");
            sb.AppendLine($"    \"partyMovedDistanceChanged\": {JsonBool(deltas.PartyMovedDistanceChanged)},");
            sb.AppendLine($"    \"maxDistanceFromStart\": {JsonDouble(deltas.MaxDistanceFromStart)},");
            sb.AppendLine($"    \"startDistanceToTarget\": {JsonNullableDouble(deltas.StartDistanceToTarget)},");
            sb.AppendLine($"    \"lastDistanceToTarget\": {JsonNullableDouble(deltas.LastDistanceToTarget)}");
            sb.AppendLine("  },");
        }

        private static string JsonString(string value)
        {
            return value == null ? "null" : "\"" + Escape(value) + "\"";
        }

        private static string JsonBool(bool value)
        {
            return value ? "true" : "false";
        }

        private static string JsonDouble(double value)
        {
            return value.ToString("0.###", CultureInfo.InvariantCulture);
        }

        private static string JsonNullableDouble(double? value)
        {
            return value.HasValue ? JsonDouble(value.Value) : "null";
        }

        private static string Escape(string value)
        {
            return (value ?? string.Empty).Replace("\\", "\\\\").Replace("\"", "\\\"");
        }
    }
}