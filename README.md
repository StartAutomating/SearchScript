# SearchScript

Search PowerShell Scripts

## Introduction

Every once in a while, we've got to search our scripts, often to make a particular update.

Sadly, we're often falling back on Select-String to do this.

This isn't ideal, because this means we lose the context around our scripts.

So why not make a quick tool to search PowerShell ScriptBlocks using the Abstract Syntax Tree?

## Installing and Importing

We can install SearchScript from the PowerShell gallery:

~~~PowerShell
# Install the module from the gallery
Install-Module SearchScript -Scope CurrentUser
~~~

After it is installed, we can import it with:

~~~PowerShell
Import-Module SearchScript -PassThru
~~~

We can also clone the repository and import the module locally:

~~~PowerShell
git clone https://github.com/StartAutomating/SearchScript.git
cd ./SearchScript
Import-Module ./ -PassThru
~~~

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


Suppose we want to update any scripts that use Invoke-WebRequest, in order to address [CVE-2025-54100](https://msrc.microsoft.com/update-guide/vulnerability/CVE-2025-54100).

We can use a little bit of Regex to identify them, but it gets a _lot_ trickier to write a pattern that will find if it's already fixed or not.

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

