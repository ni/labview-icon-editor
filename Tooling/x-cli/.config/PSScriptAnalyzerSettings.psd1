@{
    # PSScriptAnalyzer settings for this repo.
    # Rationale:
    # - PSAvoidUsingInvokeExpression: We avoid Invoke-Expression for security; keep enabled (Error).
    # - PSAvoidUsingWriteHost: Allowed for user-facing CLI output; downgrade to Information.
    # - PSUseDeclaredVarsMoreThanAssignments: Useful but noisy in CI; keep Warning.
    
    Severity = @('Error','Warning','Information')

    Rules = @{
        PSAvoidUsingInvokeExpression = @{ Severity = 'Error' }
        PSAvoidUsingWriteHost       = @{ Severity = 'Information' }
    }
}

