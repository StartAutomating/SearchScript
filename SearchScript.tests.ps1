describe SearchScript {
    it 'Just searches scripts' {
        Get-Command -Module SearchScript |
            Search-Script
    }

    it 'Can search for a specific element' {
        $testCaseAst = 
            @(Get-Command $MyInvocation.MyCommand.ScriptBlock.File |
                Search-Script -For {
                    param($ast)

                    $ast.CommandElements -and $ast.CommandElements[0] -match '^(?>it|context|describe)'
                })
        "$($testCaseAst.CommandElements[0])" | Should -Be 'describe'
    }
}
