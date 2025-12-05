# Stub module for MipScenarioHelpers
function Get-MipScenarioStatus {
    [CmdletBinding()] param()
    return @{ status = 'stub'; message = 'MipScenarioHelpers not available' }
}
Export-ModuleMember -Function Get-MipScenarioStatus
