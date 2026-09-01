[CmdletBinding()]
param(
    [string]$ProxyUrl,
    [string]$ProxifierProfile = "$env:APPDATA\Proxifier4\Profiles\unity.ppx",
    [switch]$SkipNetwork
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-TcpPort {
    param(
        [Parameter(Mandatory)] [string]$HostName,
        [Parameter(Mandatory)] [int]$Port,
        [int]$TimeoutMilliseconds = 3000
    )

    $client = [System.Net.Sockets.TcpClient]::new()
    try {
        $task = $client.ConnectAsync($HostName, $Port)
        if (-not $task.Wait($TimeoutMilliseconds)) {
            return $false
        }
        return $client.Connected
    }
    catch {
        return $false
    }
    finally {
        $client.Dispose()
    }
}

function Get-RuleText {
    param(
        [System.Xml.XmlElement[]]$Rules,
        [string]$Property
    )

    $values = $Rules | ForEach-Object {
        $node = $_.SelectSingleNode("./*[local-name()='$Property']")
        if ($node) {
            $node.InnerText
        }
    }

    return (($values) -join ';').ToLowerInvariant()
}

$unityCommands = @(Get-Command unity -All -CommandType Application -ErrorAction SilentlyContinue)
$activeUnity = $unityCommands | Select-Object -First 1
$unityVersion = $null
$signatureStatus = $null
$signatureSigner = $null
$updateCurrent = $null
$updateLatest = $null
$authExitCode = $null

if ($activeUnity) {
    $unityVersion = ((& $activeUnity.Source --version 2>$null) | Select-Object -First 1).Trim()
    $signature = Get-AuthenticodeSignature -LiteralPath $activeUnity.Source
    $signatureStatus = [string]$signature.Status
    if ($signature.SignerCertificate) {
        $signatureSigner = [string]$signature.SignerCertificate.Subject
    }
}

if (-not $ProxyUrl) {
    $candidatePorts = @(7897, 7890, 7891)
    $listeners = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue)
    $detectedPort = $candidatePorts |
        Where-Object { $listeners.LocalPort -contains $_ } |
        Select-Object -First 1
    if ($detectedPort) {
        $ProxyUrl = "http://127.0.0.1:$detectedPort"
    }
}

$proxyDisplay = $null
$proxyReachable = $false
$unityEndpointReachable = $null
$unityEndpointFinalHost = $null
$googleEndpointReachable = $null
$googleEndpointFinalHost = $null

if ($ProxyUrl) {
    try {
        $proxyUri = [uri]$ProxyUrl
        $proxyDisplay = '{0}://{1}:{2}' -f $proxyUri.Scheme, $proxyUri.Host, $proxyUri.Port
        $proxyReachable = Test-TcpPort -HostName $proxyUri.Host -Port $proxyUri.Port

        if (-not $SkipNetwork -and $proxyReachable) {
            try {
                $unityResponse = Invoke-WebRequest -Uri 'https://id.unity.com/' -Proxy $ProxyUrl `
                    -UseBasicParsing -TimeoutSec 20 -MaximumRedirection 5
                $unityEndpointReachable = $true
                $unityEndpointFinalHost = [string]$unityResponse.BaseResponse.RequestMessage.RequestUri.Host
            }
            catch {
                $unityEndpointReachable = $false
            }

            try {
                $googleResponse = Invoke-WebRequest -Uri 'https://accounts.google.com/' -Proxy $ProxyUrl `
                    -UseBasicParsing -TimeoutSec 20 -MaximumRedirection 5
                $googleEndpointReachable = $true
                $googleEndpointFinalHost = [string]$googleResponse.BaseResponse.RequestMessage.RequestUri.Host
            }
            catch {
                $googleEndpointReachable = $false
            }
        }
    }
    catch {
        $proxyDisplay = '<invalid proxy URL>'
    }
}

if ($activeUnity -and -not $SkipNetwork) {
    try {
        $upgradeArguments = @('--format', 'json')
        if ($ProxyUrl) {
            $upgradeArguments += @('--proxy', $ProxyUrl)
        }
        $upgradeArguments += @('upgrade', '--check')
        $upgradeOutput = & $activeUnity.Source @upgradeArguments 2>$null
        $upgradeResult = $upgradeOutput | ConvertFrom-Json
        $updateCurrent = [string]$upgradeResult.data.currentVersion
        $updateLatest = [string]$upgradeResult.data.latestVersion
    }
    catch {
        $updateCurrent = $unityVersion
    }

    try {
        $authArguments = @('--format', 'json')
        if ($ProxyUrl) {
            $authArguments += @('--proxy', $ProxyUrl)
        }
        $authArguments += @('auth', 'status')
        $null = & $activeUnity.Source @authArguments 2>$null
        $authExitCode = $LASTEXITCODE
    }
    catch {
        $authExitCode = $LASTEXITCODE
    }
}

$profileExists = Test-Path -LiteralPath $ProxifierProfile
$proxifierProxyConfigured = $false
$proxifierUnityTargets = $false
$proxifierBrowserProcess = $false
$proxifierLocalhostRule = $false
$proxifierClashProcess = $false

if ($profileExists) {
    try {
        [xml]$profileXml = Get-Content -Raw -LiteralPath $ProxifierProfile
        $proxyNodes = @($profileXml.SelectNodes("//*[local-name()='Proxy']"))
        $ruleNodes = @($profileXml.SelectNodes("//*[local-name()='Rule']"))
        $applicationText = Get-RuleText -Rules $ruleNodes -Property 'Applications'
        $targetText = Get-RuleText -Rules $ruleNodes -Property 'Targets'

        $proxifierProxyConfigured = @($proxyNodes | Where-Object {
            ([string]$_.Address -eq '127.0.0.1') -and ([int]$_.Port -gt 0)
        }).Count -gt 0
        $proxifierUnityTargets = $targetText -match 'unity\.com|unity3d\.com'
        $proxifierBrowserProcess = $applicationText -match 'chrome\.exe|msedge\.exe'
        $proxifierLocalhostRule = $targetText -match 'localhost|127\.0\.0\.1'
        $proxifierClashProcess = $applicationText -match 'clash-verge\.exe|verge-mihomo\.exe|clash\.exe'
    }
    catch {
        $profileExists = $false
    }
}

$pipelineReachable = Test-TcpPort -HostName '127.0.0.1' -Port 7800 -TimeoutMilliseconds 1000
$wingetAvailable = [bool](Get-Command winget -ErrorAction SilentlyContinue)
$wingetPackageAvailable = $null
if ($wingetAvailable -and -not $SkipNetwork) {
    & winget show --id Unity.CLI --exact --accept-source-agreements --disable-interactivity *> $null
    $wingetPackageAvailable = $LASTEXITCODE -eq 0
}

[pscustomobject]@{
    Timestamp = (Get-Date).ToString('o')
    UnityCli = [pscustomobject]@{
        Found = [bool]$activeUnity
        ActivePath = if ($activeUnity) { $activeUnity.Source } else { $null }
        ShadowCopyCount = [Math]::Max(0, $unityCommands.Count - 1)
        Version = $unityVersion
        SignatureStatus = $signatureStatus
        SignerIsUnity = [bool]($signatureSigner -match 'Unity Technologies')
        UpdateCurrent = $updateCurrent
        UpdateLatestFromConfiguredManifest = $updateLatest
        AuthStatusExitCode = $authExitCode
    }
    Proxy = [pscustomobject]@{
        Address = $proxyDisplay
        TcpReachable = $proxyReachable
        UnityEndpointReachable = $unityEndpointReachable
        UnityEndpointFinalHost = $unityEndpointFinalHost
        UnityEndpointRedirectedToChina = [bool]($unityEndpointFinalHost -match '(^|\.)unity\.cn$|(^|\.)unity3d\.cn$')
        GoogleEndpointReachable = $googleEndpointReachable
        GoogleEndpointFinalHost = $googleEndpointFinalHost
    }
    Proxifier = [pscustomobject]@{
        ProfilePath = $ProxifierProfile
        ProfileReadable = $profileExists
        LocalProxyConfigured = $proxifierProxyConfigured
        UnityTargetsPresent = $proxifierUnityTargets
        BrowserProcessPresent = $proxifierBrowserProcess
        LocalhostRulePresent = $proxifierLocalhostRule
        ClashProcessRulePresent = $proxifierClashProcess
    }
    Pipeline = [pscustomobject]@{
        DefaultPort7800Reachable = $pipelineReachable
    }
    Winget = [pscustomobject]@{
        Available = $wingetAvailable
        UnityCliPackageAvailable = $wingetPackageAvailable
    }
}
