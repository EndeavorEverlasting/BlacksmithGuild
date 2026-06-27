using System;

namespace BlacksmithGuild.CampaignRuntime
{
    public sealed class CampaignActivityHandoff
    {
        public string HandoffId { get; set; }
        public string ActivityId { get; set; }
        public string OccurredUtc { get; set; }
        public string FromEngine { get; set; }
        public string ToEngine { get; set; }
        public string GovernorMode { get; set; }
        public string Stage { get; set; }
        public string Status { get; set; }
        public bool MutationAuthorized { get; set; }
        public bool MutationApplied { get; set; }
        public string ExpectedProof { get; set; }
        public string Detail { get; set; }
    }

    public static class CampaignActivityHandoffRecorder
    {
        public static void RecordRequest(
            CampaignActivityRequest request,
            string fromEngine,
            string toEngine,
            string stage,
            string status,
            string detail)
        {
            if (request == null)
            {
                return;
            }

            request.HandoffTrail.Add(Create(
                request.ActivityId,
                fromEngine,
                toEngine,
                request.Mode,
                stage,
                status,
                request.MutationAuthorized,
                mutationApplied: false,
                request.ExpectedProof,
                detail));
        }

        public static CampaignActivityResult RecordResult(
            CampaignActivityRequest request,
            CampaignActivityResult result,
            string fromEngine,
            string toEngine,
            string stage,
            string detail)
        {
            if (result == null)
            {
                return null;
            }

            if (request != null)
            {
                for (var i = 0; i < request.HandoffTrail.Count; i++)
                {
                    result.HandoffTrail.Add(request.HandoffTrail[i]);
                }
            }

            result.HandoffTrail.Add(Create(
                result.ActivityId ?? request?.ActivityId,
                fromEngine,
                toEngine,
                request?.Mode,
                stage,
                result.Status,
                request != null && request.MutationAuthorized,
                result.MutationApplied,
                request?.ExpectedProof,
                detail));

            return result;
        }

        private static CampaignActivityHandoff Create(
            string activityId,
            string fromEngine,
            string toEngine,
            string governorMode,
            string stage,
            string status,
            bool mutationAuthorized,
            bool mutationApplied,
            string expectedProof,
            string detail)
        {
            return new CampaignActivityHandoff
            {
                HandoffId = Guid.NewGuid().ToString("N"),
                ActivityId = activityId,
                OccurredUtc = DateTime.UtcNow.ToString("o"),
                FromEngine = fromEngine,
                ToEngine = toEngine,
                GovernorMode = governorMode,
                Stage = stage,
                Status = status,
                MutationAuthorized = mutationAuthorized,
                MutationApplied = mutationApplied,
                ExpectedProof = expectedProof,
                Detail = detail
            };
        }
    }
}
