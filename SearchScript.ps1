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
    dir *.ps1 | Get-Command { $_ } | SearchScript
.EXAMPLE
    # Get every type reference in the current directory
    dir *.ps1 |
        Get-Command { $_ } |
            SearchScript -For { param($ast) $ast.TypeName }
.EXAMPLE
    # Get every type reference in the current directory
    # then get their reflected type
    dir *.ps1 |
        Get-Command { $_ } |
            SearchScript -For {
                param($ast) $ast.TypeName.GetReflectionType
            } |
                Foreach-Object {
                    $_.TypeName.GetReflectionType()
                }
.EXAMPLE
    # Get every command reference in the module search script
    Get-Command Search-Script |
        Search-Script -For {
            param($ast) $ast -is [Management.Automation.Language.CommandAst]
        }
.EXAMPLE
    # Get every `[Management.Automation.Language.VariableAst]` in Search-Script
    Get-Command Search-Script |
        Search-Script -For ([Management.Automation.Language.VariableAst])        
.EXAMPLE
    # Search Script for every `[type]`
    Get-Command Search-Script |        
        Search-Script -For ([type])
.EXAMPLE
    # Search-Script for every `[ScriptBlock]`
    Get-Command Search-Script |
        Search-Script -For ([ScriptBlock])
.EXAMPLE
    # Get every `[ScriptBlock]` and `[string]` reference in Search-Script
    Get-Command Search-Script |        
        Search-Script -For ([ScriptBlock], [string])
.EXAMPLE
    # Get every `[IComparable]` reference in Search-Script
    Get-Command Search-Script |        
        Search-Script -For ([IComparable])
.EXAMPLE
    # Search for scripts that may be impacted by
    # [CVE-2025-54100](https://msrc.microsoft.com/update-guide/vulnerability/CVE-2025-54100)
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
[ArgumentCompleter({
    <#
    .SYNOPSIS
        History Completer
    .DESCRIPTION
        History Argument Completer for a function.
        
        This looks thru the current session history for uses of this command.
    #>
    param($wordToComplete, $commandAst, $cursorPosition)    
    
    # Whenever we find a match, we need all elements except the one being completed    
    $upTilNow = foreach ($element in $commandAst.CommandElements) {
        if ($element.Extent.EndOffset -ge $cursorPosition) {
            break
        }
        $element
    }
    
    # Now, to find any matching history entries, we Get-History
    @(
        foreach ($historyItem in Get-History) {
            # looking for things that are _like_ the entire ast
            if ($historyItem.CommandLine -like "$upTilNow*") {
                # and returning the current word(s) to complete
                # replacing any leading whitespaces, so we don't tab too much.
                $historyItem.CommandLine.Substring("$upTilNow".Length) -replace '^\s+'
            }
        }
    )
})]
param(
# The script to search.
[Parameter(ValueFromPipeline,ValueFromPipelineByPropertyName)]
[Alias('ScriptBlock','Definition','Haystack')]
[ScriptBlock]
$Script,

# What we're searching for.
# 
# Can be a ScriptBlock, string, regex, type, or ast function.
# 
# If a string is provided, it will be treated as a literal,
# unless it starts and ends with `/`.
[ValidateScript({
    $validTypes = 
        [ScriptBlock],
        [string],
        [Regex],
        [type],
        [Func[Management.Automation.Language.Ast,bool]]
    foreach ($validType in $validTypes) {
        if ($_ -is $validType) { return $true}
    }
    throw "must be [$($validTypes -join '] or [')]"
})]
[Alias('Pattern','Needle','Predicate','SearchScript')]
[PSObject]
$For = [string]"/./",

# If set, will perform a shallow search.
# By default will search a scriptblock and nested blocks.
[switch]
$Shallow
)

process {
    # If the script has no Ast, return
    if (-not $script.Ast) { return }

    # If `-For` is a `[String]` or `[Regex]`,
    # make sure we sanitize our input.
    # ![Exploits of a Mom](https://xkcd.com/327/)

    # If `-For` is a `[string]`
    if ($for -is [string]) {
        # the operator is -eq by default.
        $operator = '-eq'
        # If it takes the form of a regex literal 
        if ($for -match '^/.+/$') {
            # strip the slashes
            $for =
                $for -replace '^/' -replace '/$'
            # and match instead.
            $operator = '-match'
        }
        # Create a `[Scriptblock]` that finds exactly that string.
        $for = [ScriptBlock]::Create("param(`$ast) `$ast.Extent.ToString() $operator '$(
            # Always double single quotes to avoid code injection.
            $for -replace "'","''"
        )'")
    }

    # If `-For` is a `[Regex]`
    if ($for -is [Regex]) {
        $for =
            # Create a `[ScriptBlock]` that matches that pattern.
            [ScriptBlock]::Create("param(`$ast) `$pattern = [Regex]::new('$(
                # Always double single quotes to avoid code injection.
                $for -replace "'","''"
            )','$($for.Options)'); `$ast -match `$pattern")
    }

    if ($For -as [type[]]) {
        $for =
            # Create a `[ScriptBlock]` that looks for that type.
            # This one is more complicated, so we will create it in two parts 
            [ScriptBlock]::Create((
(@(
    # dynamically create the list of types
    'param($ast)'
    "`$types = @("
    foreach ($forType in $for) {
        $forType = $forType -as [type]
        if (-not $forType) { continue }
        "[$($forType.FullName)]"
    }    
    ")"     
) -join [Environment]::NewLine) + {
# Find a reflected type, if there is one.
$reflectedType = 
    if ($ast.TypeName.GetReflectionType) {
        $ast.TypeName.GetReflectionType()
    } else {
        $null   
    }

# Go over each of our potential types
# Several conditions would be a use of our type
foreach ($type in $types) {
    # * If the ast is that type, return true
    if ($ast -is $type) { return $true } 
    if (-not $reflectedType) { continue }
    # * If the reflected type is exactly that type, return true
    if ($reflectedType -eq $type) { return $true }
    # * If the reflected type is a subclass of that type, return true
    if ($reflectedType.IsSubClassOf($type)) { return $true }
    # * If the type is an interface,
    #   return true if the reflected type implements it    
    if ($type.IsInterface -and $reflectedType.GetInterface($type)) {
        return $true
    }
}
# Returning nothing will be falsy, and will not return the element.
}
            ))
    }
    
    if ($VerbosePreference -notin 'silentlyContinue', 'ignore') {
        Write-Verbose "Searching Script For {$for}"
    }
    # Call `.FindAll` and let our results flow
    $Script.Ast.FindAll($for, -not $Shallow)
}
