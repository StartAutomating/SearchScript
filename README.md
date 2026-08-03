# SearchScript
[![SearchScript](https://img.shields.io/powershellgallery/dt/SearchScript)](https://www.powershellgallery.com/packages/SearchScript/)
## Search PowerShell Scripts
## Introduction

Every once in a while, we've got to search our scripts, often to make a particular update.

Sadly, we're often falling back on Select-String to do this.

This isn't ideal, because this means we lose the context around our scripts.

So why not make a quick tool to search PowerShell ScriptBlocks using the Abstract Syntax Tree?

## Examples

Let's start simple.  As a general rule, we don't want to use Invoke-Expression in our scripts.

We can find any matching part of the syntax tree:

~~~PowerShell
{
    iex "'I could do anything'"    
}, {
    Invoke-Expression "IsBad, ok"
}, {
    "this is fine"
} | 
    Search-Script -For "^(iex|Invoke-Expression)"
~~~

Suppose we want to update any scripts that use Invoke-WebRequest,
in order to address [CVE-2025-54100](https://msrc.microsoft.com/update-guide/vulnerability/CVE-2025-54100).

We can use a little bit of Regex to identify them,
but it gets a _lot_ trickier to write a pattern that will find if it's already fixed or not.

If we could just see that they use -UseBasicParsing, then it's already been fixed.

This little script helps us tell the difference:

~~~PowerShell
{    
    Invoke-WebRequest -Url $NotOK # not yet fixed
},{    
    Invoke-WebRequest -Url $OK -UseBasicParsing # already fixed
} |
    Search-Script -For {
        param($ast)
        if (-not $ast.CommandElements -or (
            $ast.CommandElements[0] -notmatch 'Invoke-WebRequest|curl|iwr'
        )) {
            return $false
        }
        if (-not ($ast.CommandElements -match '-UseBasicParsing')) { return $true }
        return $false
    }
~~~

## Installing and Importing

You can install SearchScript from the [PowerShell gallery](https://powershellgallery.com/)

~~~PowerShell
Install-Module SearchScript -Scope CurrentUser -Force
~~~

Once installed, you can import the module with:

~~~PowerShell
Import-Module SearchScript -PassThru
~~~


You can also clone the repo and import the module locally:

~~~PowerShell
git clone https://github.com/StartAutomating/SearchScript/
cd ./SearchScript
Import-Module ./ -PassThru
~~~

## Functions
SearchScript has 1 function
### Search-Script
#### Searches Scripts
Searches PowerShell scripts, using the Abstract Syntax Tree.

This can quickly and easily find any part of any script in any file.
##### Parameters

|Name|Type|Description|
|-|-|-|
|Script|ScriptBlock|The script to search|
|For|PSObject|What we're searching for.<br/>Can be a ScriptBlock, string, regex, or ast function<br/>If a strign is provided, it will be treated as a pattern.|
|Shallow|SwitchParameter|If set, will perform a shallow search.<br/>By default will search a scriptblock and nested blocks.|

##### Examples
###### Example 1
Get every part of every script in this module.
~~~PowerShell
Get-Command -Module SearchScript | SearchScript
~~~
###### Example 2
Get every part of every script in the current directory
~~~PowerShell
dir *.ps1 | Get-Command { $_ } | SearchScript
~~~
###### Example 3
Get every type reference in the current directory
~~~PowerShell
dir *.ps1 |
    Get-Command { $_ } |
        SearchScript -For { param($ast) $ast.TypeName }
~~~
###### Example 4
Get every type reference in the current directory
then get their reflected type
~~~PowerShell
dir *.ps1 |
    Get-Command { $_ } |
        SearchScript -For {
            param($ast) $ast.TypeName.GetReflectionType
        } |
            Foreach-Object {
                $_.TypeName.GetReflectionType()
            }
~~~
###### Example 5
Get every command reference in the module search script
~~~PowerShell
Get-Command Search-Script |
    Search-Script -For {
        param($ast) $ast -is [Management.Automation.Language.CommandAst]
    }
~~~
###### Example 6
Get every `[Management.Automation.Language.VariableAst]` in Search-Script
~~~PowerShell
Get-Command Search-Script |
    Search-Script -For ([Management.Automation.Language.VariableAst])
~~~
###### Example 7
Search Script for every `[type]`
~~~PowerShell
Get-Command Search-Script |        
    Search-Script -For ([type])
~~~
###### Example 8
Search-Script for every `[ScriptBlock]`
~~~PowerShell
Get-Command Search-Script |
    Search-Script -For ([ScriptBlock])
~~~
###### Example 9
Get every `[ScriptBlock]` and `[string]` reference in Search-Script
~~~PowerShell
Get-Command Search-Script |        
    Search-Script -For ([ScriptBlock], [string])
~~~
###### Example 10
Get every `[IComparable]` reference in Search-Script
~~~PowerShell
Get-Command Search-Script |        
    Search-Script -For ([IComparable])
~~~
###### Example 11
Search for scripts that may be impacted by CVE-2025-54100
~~~PowerShell
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
~~~
