using System;
using BlacksmithGuild.CampaignRuntime.Adapters;
using BlacksmithGuild.DevTools;

namespace BlacksmithGuild.CampaignRuntime
{
    public static class CampaignActivityDispatcher
    {
        private static readonly ICampaignActivityAdapter[] Adapters =
        {
            new FoodActivityAdapter(),
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
                if (request.MutationAuthorized && !DevToolsConfig.CampaignRuntimeGovernorAllowBoundedExecution)
                {
                    return Result(request, CampaignActivityStatus.Blocked, "bounded execution disabled by governor config", false, "bounded_execution_disabled");
                }

                for (var i = 0; i < Adapters.Length; i++)
                {
                    if (Adapters[i].CanHandle(request))
                    {
                        return Normalize(request, Adapters[i].TryHandle(request));
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
            return new CampaignActivityResult
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
        }

        private static CampaignActivityResult Normalize(CampaignActivityRequest request, CampaignActivityResult result)
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

            return result;
        }

        private static CampaignActivityResult Result(CampaignActivityRequest request, CampaignActivityStatus status, string detail, bool mutationApplied, string failureClass)
        {
            return new CampaignActivityResult
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
        }
    }
}
