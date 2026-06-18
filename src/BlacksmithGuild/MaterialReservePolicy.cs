namespace BlacksmithGuild
{
    public sealed class MaterialReservePolicy
    {
        public int MinimumIron { get; set; } = 10;
        public int MinimumSteel { get; set; } = 5;
        public int MinimumFineSteel { get; set; } = 3;
        public int MinimumThamaskeneSteel { get; set; } = 2;

        public bool PreserveRareMaterials { get; set; } = true;
    }
}
