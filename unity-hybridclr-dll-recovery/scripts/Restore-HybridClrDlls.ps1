#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$InputDirectory,
    [Parameter(Mandatory)][string]$OutputDirectory,
    [Parameter(Mandatory)][string]$ParametersPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Reflection.Metadata

function Read-ManagedInfo([byte[]]$Bytes) {
    $stream = [IO.MemoryStream]::new($Bytes, $false)
    $reader = $null
    try {
        $reader = [System.Reflection.PortableExecutable.PEReader]::new($stream)
        if (-not $reader.HasMetadata -or $null -eq $reader.PEHeaders.CorHeader) {
            throw 'PE has no CLR metadata.'
        }
        $metadata = [System.Reflection.Metadata.PEReaderExtensions]::GetMetadataReader($reader)
        if (-not $metadata.IsAssembly) { throw 'CLR metadata is not an assembly.' }
        $assembly = $metadata.GetAssemblyDefinition()
        $bodies = 0
        $noBody = 0
        $ldnullThrow = 0
        foreach ($handle in $metadata.MethodDefinitions) {
            $method = $metadata.GetMethodDefinition($handle)
            if ($method.RelativeVirtualAddress -eq 0) { $noBody++; continue }
            $il = [System.Reflection.Metadata.PEReaderExtensions]::GetMethodBody(
                $reader, $method.RelativeVirtualAddress).GetILBytes()
            $bodies++
            if ($il.Length -eq 2 -and $il[0] -eq 0x14 -and $il[1] -eq 0x7a) { $ldnullThrow++ }
        }
        return [ordered]@{
            assembly = $metadata.GetString($assembly.Name)
            version = $assembly.Version.ToString()
            method_definitions = $metadata.MethodDefinitions.Count
            method_bodies = $bodies
            no_body = $noBody
            ldnull_throw = $ldnullThrow
        }
    }
    finally {
        if ($reader) { $reader.Dispose() }
        $stream.Dispose()
    }
}

$source = (Get-Item -LiteralPath $InputDirectory).FullName
if (-not (Test-Path -LiteralPath $source -PathType Container)) { throw 'Input must be a directory.' }
$destination = [IO.Path]::GetFullPath($OutputDirectory)
$sourcePrefix = $source.TrimEnd([char[]]'\/') + [IO.Path]::DirectorySeparatorChar
if ($destination.Equals($source, [StringComparison]::OrdinalIgnoreCase) -or
    $destination.StartsWith($sourcePrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Output must be separate from and outside the input directory.'
}
if (Test-Path -LiteralPath $destination) {
    if (-not (Test-Path -LiteralPath $destination -PathType Container) -or
        @(Get-ChildItem -LiteralPath $destination -Force).Count -gt 0) {
        throw 'Output must be a new or empty directory; no files were changed.'
    }
}

$parameters = Get-Content -LiteralPath $ParametersPath -Raw | ConvertFrom-Json
[byte[]]$keyBytes = [Convert]::FromHexString($parameters.key_hex)
[byte[]]$ivBytes = [Convert]::FromHexString($parameters.iv_hex)
if ($keyBytes.Length -notin 16,24,32 -or $ivBytes.Length -ne 16) { throw 'Invalid AES key or IV length.' }
$candidates = @(Get-ChildItem -LiteralPath $source -Recurse -File |
    Where-Object { $_.Name -match '(?i)\.dll(?:\.bytes)?$' } | Sort-Object FullName)
if ($candidates.Count -eq 0) { throw 'No .dll or .dll.bytes candidates found.' }
[IO.Directory]::CreateDirectory($destination) | Out-Null
$rows = [Collections.Generic.List[object]]::new()
$failures = 0

foreach ($file in $candidates) {
    $row = [ordered]@{ source = $file.FullName; status = 'error' }
    try {
        [byte[]]$bytes = [IO.File]::ReadAllBytes($file.FullName)
        $row.input_size = $bytes.Length
        $row.input_sha256 = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
        $isMz = $bytes.Length -ge 2 -and $bytes[0] -eq 0x4d -and $bytes[1] -eq 0x5a
        if ($isMz) {
            # A malformed MZ file fails validation rather than being silently decrypted.
            $info = Read-ManagedInfo $bytes
            [byte[]]$decoded = $bytes
            $operation = 'copied'
        }
        else {
            if ($bytes.Length -eq 0 -or ($bytes.Length % 16) -ne 0) {
                throw 'Ciphertext must have a positive length divisible by 16.'
            }
            $aes = [Security.Cryptography.Aes]::Create()
            $decryptor = $null
            try {
                $aes.Mode = [Security.Cryptography.CipherMode]::CBC
                $aes.Padding = [Security.Cryptography.PaddingMode]::PKCS7
                $decryptor = $aes.CreateDecryptor($keyBytes, $ivBytes)
                [byte[]]$decoded = $decryptor.TransformFinalBlock($bytes, 0, $bytes.Length)
            }
            finally {
                if ($decryptor) { $decryptor.Dispose() }
                $aes.Dispose()
            }
            $info = Read-ManagedInfo $decoded
            $operation = 'decrypted'
        }
        # Use the real assembly identity, not the extractor's collision-safe hash name,
        # so ILSpy can resolve sibling assembly references by their canonical names.
        $assemblyName = [string]$info.assembly
        if ([string]::IsNullOrWhiteSpace($assemblyName) -or
            $assemblyName.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0 -or
            $assemblyName.Contains('/') -or $assemblyName.Contains('\')) {
            throw 'Assembly identity cannot be used as a safe filename.'
        }
        $target = Join-Path $destination ($assemblyName + '.dll')
        if (Test-Path -LiteralPath $target) {
            throw "Duplicate assembly identity: $assemblyName. Select one matching cache version per assembly."
        }
        [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target)) | Out-Null
        # CreateNew also prevents replacement if another process creates the target.
        $outputStream = [IO.File]::Open($target, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write)
        try { $outputStream.Write($decoded, 0, $decoded.Length) } finally { $outputStream.Dispose() }
        $row.status = $operation
        $row.output = $target
        $row.output_size = $decoded.Length
        $row.output_sha256 = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($decoded)).ToLowerInvariant()
        $row.managed = $info
        Write-Host "$operation : $($file.Name) ($($info.method_bodies) method bodies)"
    }
    catch {
        $row.error = $_.Exception.Message
        $failures++
        Write-Warning "$($file.Name): $($row.error)"
    }
    $rows.Add([pscustomobject]$row)
}

$manifest = [ordered]@{
    algorithm = 'AES-CBC/PKCS7 (loader-derived parameters supplied separately)'
    input_directory = $source
    copied = @($rows | Where-Object status -eq 'copied').Count
    decrypted = @($rows | Where-Object status -eq 'decrypted').Count
    errors = $failures
    files = $rows.ToArray()
}
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $destination 'recovery-index.json') -Encoding utf8
if ($failures -gt 0) { throw "$failures candidate(s) failed; inspect recovery-index.json. Successful outputs were preserved." }
Write-Host "Recovered $($rows.Count) managed assemblies. Inspect method evidence before claiming full recovery."
