using System;
using BlacksmithGuild.CampaignRuntime.Adapters;
using BlacksmithGuild.DevTools;

namespace BlacksmithGuild.CampaignRuntime
{
    public static class CampaignActivityDispatcher
    {
        private const string DispatcherEngine = "ActivityDispatcher";

        private static readonly ICampaignActivityAdapter[] Adapters =
        {
            new FoodActivityAdapter(),
            new MarketActivityAdapter(),
            new TradeActivityAdapter(),
            new SmithingActivityAdapter(),
            new TravelActivityAdapter(),
            new HorseMarketActivityAdapter(),
            new CompanionActivityAdapter(),
            new DeferredActivityAdapter()
        };

        public static CampaignActivityResult Dispatch(CampaignActivityRequest request)
        {
            if (request == null)
            {
                return Result(null, CampaignActivityStatus.Failed, "missing activity request", false, "missing_activity_request");
            }

            try
            {
                CampaignActivityHandoffRecorder.RecordRequest(
                    request,
                    request.SourceEngine,
                    DispatcherEngine,
                    "dispatch_received",
                    CampaignActivityStatus.Started.ToString(),
                    "Dispatcher received governor activity request for routing.");

                if (request.MutationAuthorized && !DevToolsConfig.CampaignRuntimeGovernorAllowBoundedExecution)
                {
                    return Result(request, CampaignActivityStatus.Blocked, "bounded execution disabled by governor config", false, "bounded_execution_disabled");
                }

                for (var i = 0; i < Adapters.Length; i++)
                {
                    if (Adapters[i].CanHandle(request))
                    {
                        var adapterName = Adapters[i].GetType().Name;
                        CampaignActivityHandoffRecorder.RecordRequest(
                            request,
                            DispatcherEngine,
                            adapterName,
                            "adapter_selected",
                            CampaignActivityStatus.Started.ToString(),
                            "Dispatcher selected adapter for target engine " + request.TargetEngine + ".");

                        return Normalize(request, Adapters[i].TryHandle(request), adapterName);
                    }
                }

                return Result(
                    request,
                    request.MutationAuthorized ? CampaignActivityStatus.Blocked : CampaignActivityStatus.Deferred,
                    "no adapter handles target engine " + request.TargetEngine + " operation " + request.Operation,
                    false,
                    request.MutationAuthorized ? "missing_activity_adapter" : null);
            }
            catch (Exception ex)
            {
                return Result(request, CampaignActivityStatus.Failed, ex.Message, false, "activity_dispatch_exception");
            }
        }

        public static CampaignActivityResult Deferred(CampaignActivityRequest request, string detail)
        {
            return Result(request, CampaignActivityStatus.Deferred, detail, false, null);
        }

        public static CampaignActivityResult Blocked(CampaignActivityRequest request, string detail, string failureClass)
        {
            return Result(request, CampaignActivityStatus.Blocked, detail, false, failureClass);
        }

        public static CampaignActivityResult Completed(CampaignActivityRequest request, string detail, bool inventoryDeltaObserved, bool goldDeltaObserved)
        {
            var result = new CampaignActivityResult
            {
                ActivityId = request?.ActivityId,
                CompletedUtc = DateTime.UtcNow.ToString("o"),
                SourceEngine = request?.TargetEngine,
                Status = CampaignActivityStatus.Completed.ToString(),
                Detail = detail,
                MutationApplied = true,
                InventoryDeltaObserved = inventoryDeltaObserved,
                GoldDeltaObserved = goldDeltaObserved
            };

            CampaignActivityNarrativeFactory.AttachDefault(result, request, detail, null);

            return CampaignActivityHandoffRecorder.RecordResult(
                request,
                result,
                request?.TargetEngine,
                CampaignActivityEngine.Governor.ToString(),
                "adapter_completed",
                detail);
        }

        public static CampaignActivityResult CompletedReadOnly(CampaignActivityRequest request, string detail)
        {
            var result = new CampaignActivityResult
            {
                ActivityId = request?.ActivityId,
                CompletedUtc = DateTime.UtcNow.ToString("o"),
                SourceEngine = request?.TargetEngine,
                Status = CampaignActivityStatus.Completed.ToString(),
                Detail = detail,
                MutationApplied = false,
                InventoryDeltaObserved = false,
                GoldDeltaObserved = false
            };

            CampaignActivityNarrativeFactory.AttachDefault(result, request, detail, null);
            return CampaignActivityHandoffRecorder.RecordResult(
                request,
                result,
                request?.TargetEngine,
                CampaignActivityEngine.Governor.ToString(),
                "adapter_completed_read_only",
                detail);
        }

        private static CampaignActivityResult Normalize(CampaignActivityRequest request, CampaignActivityResult result, string adapterName)
        {
            if (result == null)
            {
                return Result(request, CampaignActivityStatus.Failed, "adapter returned no result", false, "missing_activity_result");
            }

            result.ActivityId = string.IsNullOrWhiteSpace(result.ActivityId) ? request?.ActivityId : result.ActivityId;
            result.CompletedUtc = string.IsNullOrWhiteSpace(result.CompletedUtc) ? DateTime.UtcNow.ToString("o") : result.CompletedUtc;
            result.SourceEngine = string.IsNullOrWhiteSpace(result.SourceEngine) ? request?.TargetEngine : result.SourceEngine;
            result.Status = string.IsNullOrWhiteSpace(result.Status) ? CampaignActivityStatus.Failed.ToString() : result.Status;

            if (!request.MutationAuthorized && result.MutationApplied)
            {
                return Result(request, CampaignActivityStatus.Failed, "adapter reported a change while request was propose-only", false, "mutation_gate_violation");
            }

            CampaignActivityNarrativeFactory.AttachDefault(result, request, result.Detail, result.FailureClass);

            return CampaignActivityHandoffRecorder.RecordResult(
                request,
                result,
                adapterName,
                CampaignActivityEngine.Governor.ToString(),
                "adapter_result",
                result.Detail);
        }

        private static CampaignActivityResult Result(CampaignActivityRequest request, CampaignActivityStatus status, string detail, bool mutationApplied, string failureClass)
        {
            var result = new CampaignActivityResult
            {
                ActivityId = request?.ActivityId,
                CompletedUtc = DateTime.UtcNow.ToString("o"),
                SourceEngine = request?.TargetEngine ?? CampaignActivityEngine.Governor.ToString(),
                Status = status.ToString(),
                Detail = detail,
                MutationApplied = mutationApplied,
                InventoryDeltaObserved = false,
                GoldDeltaObserved = false,
                FailureClass = failureClass
            };

            CampaignActivityNarrativeFactory.AttachDefault(result, request, detail, failureClass);

            return CampaignActivityHandoffRecorder.RecordResult(
                request,
                result,
                DispatcherEngine,
                CampaignActivityEngine.Governor.ToString(),
                "dispatch_result",
                detail);
        }
    }
}
