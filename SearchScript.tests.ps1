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

    it 'Can search for types' {
        @(
            Get-Command Search-Script | 
                Search-Script -For ([ScriptBlock])
        ).Length | 
            Should -BeGreaterThan 0
    }

    it 'Can search for interfaces' {
        @(
            Get-Command Search-Script | 
                Search-Script -For ([IComparable])
        ).Length |
                Should -BeGreaterThan 0
    }
}
