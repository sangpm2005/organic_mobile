param([string]$ApiBaseUrl = 'http://10.0.2.2:8088/api/v1')

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$taskTemp = Join-Path $projectRoot '.local/java-temp'
$previousCache = $env:PUB_CACHE
$previousJavaOptions = $env:JAVA_TOOL_OPTIONS
New-Item -ItemType Directory -Force $taskTemp | Out-Null
Push-Location $projectRoot
try {
    # Avoid a Windows Java Unix-socket failure with the user profile Temp path.
    $env:JAVA_TOOL_OPTIONS = ($previousJavaOptions + ' "-Djava.io.tmpdir=' + $taskTemp + '" "-Djdk.net.unixdomain.tmpdir=' + $taskTemp + '"').Trim()
    $env:PUB_CACHE = Join-Path $projectRoot '.pub-cache'
    flutter build apk --debug "--dart-define=API_BASE_URL=$ApiBaseUrl"
    if ($LASTEXITCODE -ne 0) { throw 'APK build failed. See the Flutter/Gradle output above.' }
} finally {
    $env:PUB_CACHE = $previousCache
    $env:JAVA_TOOL_OPTIONS = $previousJavaOptions
    Pop-Location
}
