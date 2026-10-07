param(
    [switch]$Install
)

$ErrorActionPreference = 'Stop'

$projectDir = (Resolve-Path $PSScriptRoot).Path
$instanceDir = (Resolve-Path (Join-Path $projectDir '..\..')).Path
$minecraftDir = Split-Path (Split-Path $instanceDir -Parent) -Parent
$installDir = Join-Path $minecraftDir 'Install'

$javaHome = 'C:\Program Files\Java\jdk-25.0.2'
$javac = Join-Path $javaHome 'bin\javac.exe'
$jarTool = Join-Path $javaHome 'bin\jar.exe'
$javap = Join-Path $javaHome 'bin\javap.exe'

$minecraftJar = Join-Path $installDir 'libraries\net\minecraft\client\1.21.1\client-1.21.1-official.jar'
$mixinJar = Join-Path $installDir 'libraries\net\fabricmc\sponge-mixin\0.15.2+mixin.0.8.7\sponge-mixin-0.15.2+mixin.0.8.7.jar'
$fmlLoaderJar = Join-Path $installDir 'libraries\net\neoforged\fancymodloader\loader\4.0.43\loader-4.0.43.jar'
$neoForgeJar = Join-Path $installDir 'libraries\net\neoforged\neoforge\21.1.248\neoforge-21.1.248-universal.jar'
$mergeToolApiJar = Join-Path $installDir 'libraries\net\neoforged\mergetool\2.0.3\mergetool-2.0.3-api.jar'
$relicsJar = Join-Path $instanceDir 'mods\relics-1.21.1-0.12.8.jar'
$tensuraJar = Join-Path $instanceDir 'mods\tensura-neoforge-2.0.1.1.jar'
$curiosJar = Join-Path $instanceDir 'mods\curios-neoforge-9.5.1+1.21.1.jar'

$requiredFiles = @(
    $javac,
    $jarTool,
    $javap,
    $minecraftJar,
    $mixinJar,
    $fmlLoaderJar,
    $neoForgeJar,
    $mergeToolApiJar,
    $relicsJar,
    $tensuraJar,
    $curiosJar
)

foreach ($requiredFile in $requiredFiles) {
    if (-not (Test-Path -LiteralPath $requiredFile)) {
        throw "Dependência de compilação não encontrada: $requiredFile"
    }
}

$buildDir = Join-Path $projectDir 'build'
$classesDir = Join-Path $buildDir 'classes'
$stagingDir = Join-Path $buildDir 'staging'
$libsDir = Join-Path $buildDir 'libs'
$jarName = 'relics-tensura-ep-compat-1.0.0.jar'
$jarPath = Join-Path $libsDir $jarName

$resolvedBuildParent = [IO.Path]::GetFullPath((Split-Path $buildDir -Parent))
if ($resolvedBuildParent -ne $projectDir) {
    throw "Diretório de build fora do projeto: $buildDir"
}

foreach ($directory in @($classesDir, $stagingDir)) {
    if (Test-Path -LiteralPath $directory) {
        Remove-Item -LiteralPath $directory -Recurse -Force
    }
}

New-Item -ItemType Directory -Force -Path $classesDir, $stagingDir, $libsDir | Out-Null

$classpath = @(
    $minecraftJar,
    $mixinJar,
    $fmlLoaderJar,
    $neoForgeJar,
    $mergeToolApiJar,
    $relicsJar,
    $tensuraJar,
    $curiosJar
) -join [IO.Path]::PathSeparator

$sources = Get-ChildItem -LiteralPath (Join-Path $projectDir 'src\main\java') -Recurse -Filter '*.java' |
    Select-Object -ExpandProperty FullName

if (-not $sources) {
    throw 'Nenhum arquivo Java encontrado.'
}

& $javac --release 21 -encoding UTF-8 -proc:none -classpath $classpath -d $classesDir $sources
if ($LASTEXITCODE -ne 0) {
    throw "A compilação falhou com o código $LASTEXITCODE."
}

$resourcesDir = Join-Path $projectDir 'src\main\resources'
Copy-Item -Path (Join-Path $resourcesDir '*') -Destination $stagingDir -Recurse
Copy-Item -Path (Join-Path $classesDir '*') -Destination $stagingDir -Recurse

if (Test-Path -LiteralPath $jarPath) {
    Remove-Item -LiteralPath $jarPath -Force
}

& $jarTool --create --file $jarPath --no-manifest -C $stagingDir .
if ($LASTEXITCODE -ne 0) {
    throw "A criação do JAR falhou com o código $LASTEXITCODE."
}

$mixinClass = 'dev.codex.relicstensuraep.mixin.RingGluttonyEpCompatMixin'
$bytecode = & $javap -classpath "$jarPath$([IO.Path]::PathSeparator)$minecraftJar$([IO.Path]::PathSeparator)$relicsJar" -p -c $mixinClass
$bytecodeText = $bytecode -join [Environment]::NewLine
if ($LASTEXITCODE -ne 0) {
    throw 'Não foi possível inspecionar o bytecode do patch de EP.'
}

$protectedEpAttributes = @(
    'tensura:max_magicule',
    'tensura:max_aura',
    'tensura:limited_spiritual_max_magicule',
    'tensura:limited_spiritual_max_aura',
    'minecraft:generic.scale'
)
foreach ($protectedAttribute in $protectedEpAttributes) {
    if ($bytecodeText -notmatch [regex]::Escape($protectedAttribute)) {
        throw "A verificação do bytecode não encontrou a proteção para $protectedAttribute."
    }
}

$targetClass = 'it.hurts.sskirillss.relics.items.relics.ring.RingOfTheSevenDeadlySinsItem'
$targetBytecode = & $javap -classpath "$relicsJar$([IO.Path]::PathSeparator)$minecraftJar$([IO.Path]::PathSeparator)$curiosJar" -p -c $targetClass
if ($LASTEXITCODE -ne 0) {
    throw 'Não foi possível inspecionar o método alvo do Relics.'
}

$curioTickStart = ($targetBytecode | Select-String -SimpleMatch 'public void curioTick(' | Select-Object -First 1).LineNumber - 1
$inventoryTickStart = ($targetBytecode | Select-String -SimpleMatch 'public void inventoryTick(' | Select-Object -First 1).LineNumber - 1
if ($curioTickStart -lt 0 -or $inventoryTickStart -le $curioTickStart) {
    throw 'O método curioTick esperado não foi encontrado no Relics.'
}

$curioTickBytecode = $targetBytecode[$curioTickStart..($inventoryTickStart - 1)] -join [Environment]::NewLine
$resetInvocationCount = [regex]::Matches($curioTickBytecode, 'EntityUtils\.resetAttribute:').Count
if ($resetInvocationCount -ne 1) {
    throw "Esperava exatamente uma aplicação de atributo no curioTick, mas encontrei $resetInvocationCount."
}

if ($Install) {
    $installedJar = Join-Path $instanceDir "mods\$jarName"
    Copy-Item -LiteralPath $jarPath -Destination $installedJar -Force
    Write-Output "Instalado: $installedJar"
}

Write-Output "Gerado e verificado: $jarPath"
