namespace BlacksmithGuild.Forge
{
    public sealed class SmithingSmeltExecutionResult
    {
        public string WeaponItemId { get; set; }
        public string WeaponName { get; set; }
        public int WeaponsBefore { get; set; }
        public int WeaponsAfter { get; set; }
        public int IronBefore { get; set; }
        public int IronAfter { get; set; }
        public int CharcoalBefore { get; set; }
        public int CharcoalAfter { get; set; }
        public string ExecutionMethod { get; set; }
        public string ActorName { get; set; }
        public bool AttemptSuccess { get; set; }
        public string Detail { get; set; }
    }

    public sealed class SmithingLootWeaponCandidate
    {
        public string ItemId { get; set; }
        public string ItemName { get; set; }
        public int Amount { get; set; }
        public int Tier { get; set; }
        public int Value { get; set; }
        public int RosterIndex { get; set; }
    }
}
