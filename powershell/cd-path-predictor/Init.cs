using System.Management.Automation;
using System.Management.Automation.Subsystem;

namespace CdPathPredictor;

public sealed class Init : IModuleAssemblyInitializer, IModuleAssemblyCleanup
{
    private static readonly Guid PredictorId = new("43e82d59-ecdf-4a55-a21a-3e7a4886c5d0");

    public void OnImport()
    {
        SubsystemManager.RegisterSubsystem(new RealCdPredictor(PredictorId));
    }

    public void OnRemove(PSModuleInfo psModuleInfo)
    {
        SubsystemManager.UnregisterSubsystem(PredictorId);
    }
}
