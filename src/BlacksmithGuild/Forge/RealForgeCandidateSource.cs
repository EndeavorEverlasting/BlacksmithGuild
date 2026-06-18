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
            detail = "Real recipe browser not implemented yet (005A scaffold).";

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

                // Sprint 005A scaffold: probe point for Bannerlord crafting/recipe APIs.
                // Return empty until real recipe enumeration is implemented in Sprint 005C+.
                detail = "Real source ready but returned zero candidates (API probe pending).";
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
