using System.Collections.Generic;

namespace BlacksmithGuild.Forge
{
    public enum ForgeCandidateSourceKind
    {
        Stub,
        Real,
        StubFallback
    }

    public enum ForgeCandidateSourceStatus
    {
        Ok,
        Unavailable,
        Empty,
        Error
    }

    public interface IForgeCandidateSource
    {
        ForgeCandidateSourceKind Kind { get; }

        bool TryGetCandidates(out IReadOnlyList<ForgeCandidate> candidates, out ForgeCandidateSourceStatus status, out string detail);
    }
}
