using System;
using System.Collections.Generic;
using BlacksmithGuild.DevTools;
using TaleWorlds.CampaignSystem;

namespace BlacksmithGuild.Forge
{
    public sealed class RealForgeCandidateSource : IForgeCandidateSource
    {
        public ForgeCandidateSourceKind Kind => ForgeCandidateSourceKind.Real;

        public bool TryGetCandidates(
            out IReadOnlyList<ForgeCandidate> candidates,
            out ForgeCandidateSourceStatus status,
            out string detail)
        {
            candidates = Array.Empty<ForgeCandidate>();
            status = ForgeCandidateSourceStatus.Unavailable;
            detail = "Real recipe browser not ready.";

            try
            {
                if (Campaign.Current == null || Hero.MainHero == null)
                {
                    detail = "Campaign not ready for real forge candidate reads.";
                    status = ForgeCandidateSourceStatus.Unavailable;
                    return false;
                }

                if (!GameSessionState.IsCampaignMapReady)
                {
                    detail = "Campaign map not ready for real forge candidate reads.";
                    status = ForgeCandidateSourceStatus.Unavailable;
                    return false;
                }

                var probeResult = ForgeRecipeProbeService.RunProbe();
                ForgeRecipeProbeService.PublishProbeResult(probeResult, "RealForgeCandidateSource", writeStructuredReport: false);

                var mapResult = ForgeRealCandidateMapper.TryMapTemplates(Hero.MainHero);
                if (mapResult.Candidates != null && mapResult.Candidates.Count > 0)
                {
                    candidates = mapResult.Candidates;
                    status = ForgeCandidateSourceStatus.Ok;
                    detail = mapResult.Detail;
                    return true;
                }

                detail = mapResult.Detail
                    ?? probeResult.Report?.Detail
                    ?? "Real source probe found no mappable candidates.";
                status = ForgeCandidateSourceStatus.Empty;
                return false;
            }
            catch (Exception ex)
            {
                detail = ex.Message;
                status = ForgeCandidateSourceStatus.Error;
                return false;
            }
        }
    }
}
