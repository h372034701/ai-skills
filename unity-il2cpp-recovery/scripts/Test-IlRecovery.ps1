[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$OutputDirectory,

    [string[]]$AssemblyName = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Reflection.Metadata

$files = Get-ChildItem -LiteralPath $OutputDirectory -Filter '*.dll' -File
if ($AssemblyName.Count -gt 0) {
    # pwsh -File passes comma-delimited values as one argument on some hosts.
    $requestedNames = @($AssemblyName | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
    $files = $files | Where-Object { $_.Name -in $requestedNames }
}

if (-not $files) {
    throw "No matching DLL files were found in '$OutputDirectory'."
}

$results = foreach ($file in $files) {
    $stream = $null
    $peReader = $null

    try {
        $stream = [System.IO.File]::OpenRead($file.FullName)
        $peReader = [System.Reflection.PortableExecutable.PEReader]::new($stream)
        $metadataReader = [System.Reflection.Metadata.PEReaderExtensions]::GetMetadataReader($peReader)

        $definitions = 0
        $methodBodies = 0
        $noBody = 0
        $ldnullThrow = 0

        foreach ($handle in $metadataReader.MethodDefinitions) {
            $definitions++
            $method = $metadataReader.GetMethodDefinition($handle)
            if ($method.RelativeVirtualAddress -eq 0) {
                $noBody++
                continue
            }

            $methodBodies++
            $il = [System.Reflection.Metadata.PEReaderExtensions]::GetMethodBody($peReader, $method.RelativeVirtualAddress).GetILBytes()
            if ($il.Length -eq 2 -and $il[0] -eq 0x14 -and $il[1] -eq 0x7A) {
                $ldnullThrow++
            }
        }

        [pscustomobject]@{
            Name        = $file.Name
            Definitions = $definitions
            MethodBodies = $methodBodies
            NoBody      = $noBody
            LdnullThrow = $ldnullThrow
            Error       = ''
        }
    }
    catch {
        [pscustomobject]@{
            Name        = $file.Name
            Definitions = 0
            MethodBodies = 0
            NoBody      = 0
            LdnullThrow = 0
            Error       = $_.Exception.Message
        }
    }
    finally {
        if ($peReader) {
            $peReader.Dispose()
        }
        if ($stream) {
            $stream.Dispose()
        }
    }
}

$summary = [pscustomobject]@{
    Files           = @($results).Count
    MethodDefinitions = ($results | Measure-Object -Property Definitions -Sum).Sum
    MethodBodies    = ($results | Measure-Object -Property MethodBodies -Sum).Sum
    NoBody          = ($results | Measure-Object -Property NoBody -Sum).Sum
    LdnullThrow     = ($results | Measure-Object -Property LdnullThrow -Sum).Sum
    FilesWithThrow  = @($results | Where-Object LdnullThrow -gt 0).Count
    Errors          = @($results | Where-Object { $_.Error }).Count
}

$summary
$results | Sort-Object Name
