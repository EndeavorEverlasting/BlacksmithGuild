namespace BlacksmithGuild.CampaignRuntime
{
    public interface ICampaignActivityAdapter
    {
        bool CanHandle(CampaignActivityRequest request);
        CampaignActivityResult TryHandle(CampaignActivityRequest request);
    }
}
