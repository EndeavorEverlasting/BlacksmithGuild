using System.Collections.Generic;

namespace BlacksmithGuild.Forge
{
    public sealed class StubForgeCandidateSource : IForgeCandidateSource
    {
        public const string SourceName = "stub";

        public ForgeCandidateSourceKind Kind => ForgeCandidateSourceKind.Stub;

        public bool TryGetCandidates(
            out IReadOnlyList<ForgeCandidate> candidates,
            out ForgeCandidateSourceStatus status,
            out string detail)
        {
            candidates = BuildCandidates();
            status = ForgeCandidateSourceStatus.Ok;
            detail = $"{candidates.Count} stub candidates";
            return candidates.Count > 0;
        }

        public static IReadOnlyList<ForgeCandidate> GetCandidates()
        {
            return BuildCandidates();
        }

        private static IReadOnlyList<ForgeCandidate> BuildCandidates()
        {
            return new List<ForgeCandidate>
            {
                new ForgeCandidate
                {
                    Id = "stub.twohanded.longwarblade",
                    WeaponClass = "Two-Handed Sword",
                    DesignName = "Long Warblade",
                    EstimatedValue = 14800,
                    EstimatedMaterialCost = 2200,
                    RareMaterialPenalty = 1350,
                    Source = SourceName
                },
                new ForgeCandidate
                {
                    Id = "stub.polearm.heavyglaive",
                    WeaponClass = "Polearm",
                    DesignName = "Heavy Glaive Pattern",
                    EstimatedValue = 11200,
                    EstimatedMaterialCost = 1200,
                    RareMaterialPenalty = 250,
                    Source = SourceName
                },
                new ForgeCandidate
                {
                    Id = "stub.onehanded.officersidearm",
                    WeaponClass = "One-Handed Sword",
                    DesignName = "Officer Sidearm",
                    EstimatedValue = 6200,
                    EstimatedMaterialCost = 900,
                    RareMaterialPenalty = 100,
                    Source = SourceName
                }
            };
        }
    }
}
