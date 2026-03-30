@{
    ModuleVersion      = '0.2.1'
    GUID               = '43e82d59-ecdf-4a55-a21a-3e7a4886c5d0'
    Author             = 'David Bastien'
    CompanyName        = 'Interrobang'
    Copyright          = 'Copyright (c) David Bastien.'
    Description        = 'Predicts only real Set-Location targets by reusing PowerShell completion and filtering to container paths.'
    PowerShellVersion  = '7.2'
    NestedModules      = @('CdPathPredictor.dll')
    FunctionsToExport  = @()
    CmdletsToExport    = @()
    VariablesToExport  = @()
    AliasesToExport    = @()
    PrivateData        = @{
        PSData = @{
            Tags = @('PSEdition_Core', 'PSReadLine', 'Predictor', 'Set-Location', 'cd')
        }
    }
}
