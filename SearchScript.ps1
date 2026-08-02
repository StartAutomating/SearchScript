<#
.SYNOPSIS
    Searches Scripts
.DESCRIPTION
    Searches PowerShell scripts, using the Abstract Syntax Tree.

    This can quickly and easily find any part of any script in any file.
.EXAMPLE
    # Get every part of every script in this module.
    Get-Command -Module SearchScript | SearchScript
.EXAMPLE
    # Get every part of every script in the current directory
    dir *.ps1 | SearchScript
.EXAMPLE
    # Search for scripts that may be impacted by CVE-2025-54100
    Search-Script { Invoke-WebRequest } {
        param($ast)            
        if (-not $ast.CommandElements -or (
            $ast.CommandElements[0] -notmatch 'Invoke-WebRequest|curl|iwr'
        )) {
            return $false
        }
        if (-not ($ast.CommandElements -match '-UseBasicParsing')) { return $true }
        return $false
    }
#>
[Alias('srsb', 'srScript','SearchScript')]
param(
# The script to search
[Parameter(ValueFromPipeline,ValueFromPipelineByPropertyName)]
[Alias('ScriptBlock','Definition','Haystack')]
[ScriptBlock]
$Script,

# What we're searching for.
# Can be a ScriptBlock, string, regex, or ast function
# If a strign is provided, it will be treated as a pattern.
[ValidateScript({
    $validTypes = 
        [ScriptBlock],
        [string],
        [Regex],
        [Func[Management.Automation.Language.Ast,bool]]
    foreach ($validType in $validTypes) {
        if ($_ -is $validType) { return $true}
    }
    throw "must be [$($validTypes -join '] or [')]"
})]
[Alias('Pattern','Needle','Predicate','SearchScript')]
[PSObject]
$For = [string]".",

# If set, will perform a shallow search.
# By default will search a scriptblock and nested blocks.
[switch]
$Shallow
)

process {
    if ($for -is [string]) {
        $for = [ScriptBlock]::Create("param(`$ast) `$ast -match '$($for -replace "'","''")'")
    }
    if ($for -is [Regex]) {
        $for = [ScriptBlock]::Create("param(`$ast) `$pattern = [Regex]::new('$($for -replace "'","''")','$($for.Options)'); `$ast -match `$pattern")
    }
    if (-not $script.Ast) { return }
    
    $Script.Ast.FindAll($for, -not $Shallow)
}
