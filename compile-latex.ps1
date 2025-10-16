<#
.SYNOPSIS
    Automatiza a compilação do TCC em LaTeX (PDF) no Windows respeitando as normas ABNT.

.DESCRIPTION
    Executa o latexmk quando disponível, garantindo a compilação completa do documento
    conforme as normas ABNT (NBR 14724, NBR 6023, NBR 10520 e correlatas). Quando o
    latexmk não estiver instalado, recorre a uma sequência manual com pdflatex e bibtex.
    O script aceita a limpeza de arquivos temporários e a escolha do engine principal.

.PARAMETER Source
    Arquivo .tex principal do projeto. O padrão é 'modelo.tex'.

.PARAMETER Engine
    Define o engine LaTeX a ser utilizado. Valores aceitos: 'pdflatex', 'xelatex' ou 'lualatex'.

.PARAMETER Clean
    Remove arquivos auxiliares gerados em compilações anteriores antes de iniciar o processo.

.EXAMPLE
    .\compile-latex.ps1
    Compila o arquivo modelo.tex com o pdflatex via latexmk, gerando o PDF final.

.EXAMPLE
    .\compile-latex.ps1 -Source meu-trabalho.tex -Engine xelatex -Clean
    Limpa artefatos temporários e recompila o documento com o xelatex.

.NOTES
    Execute no diretório raiz do projeto ou forneça o caminho completo do arquivo .tex.
    Certifique-se de que as dependências instaladas pelo script install-latex-deps.ps1
    estejam presentes para garantir conformidade com as normas ABNT.
#>

[CmdletBinding()]
param(
    [string]$Source = 'modelo.tex',
    [ValidateSet('pdflatex', 'xelatex', 'lualatex')]
    [string]$Engine = 'pdflatex',
    [switch]$Clean
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
} catch {
    Write-Verbose 'Não foi possível ajustar a codificação do console para UTF-8.'
}

function Get-CommandPath {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [switch]$Optional
    )

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if (-not $command) {
        if ($Optional) {
            return $null
        }
        throw "A ferramenta '$Name' não foi localizada no PATH. Instale-a antes de prosseguir."
    }
    return $command.Path
}

$resolvedSource = Resolve-Path -Path $Source -ErrorAction Stop
$workingDirectory = Split-Path -Path $resolvedSource -Parent
$texFile = Split-Path -Path $resolvedSource -Leaf
$baseName = [System.IO.Path]::GetFileNameWithoutExtension($texFile)

$latexmkPath = Get-CommandPath -Name 'latexmk' -Optional
$enginePath = Get-CommandPath -Name $Engine
$bibtexPath = Get-CommandPath -Name 'bibtex' -Optional
$latexmkBaseArgs = @()

function Find-TlmgrExecutable {
    $commandNames = @('tlmgr.bat', 'tlmgr.exe', 'tlmgr')
    foreach ($name in $commandNames) {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($command) {
            return $command.Path
        }
    }

    $candidateDirectories = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
    $searchRoots = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)

    $pathEntries = $env:PATH -split ';'
    foreach ($entry in $pathEntries) {
        if ([string]::IsNullOrWhiteSpace($entry)) { continue }
        if ($entry -notlike '*texlive*') { continue }
        $resolvedEntries = Resolve-Path -Path $entry -ErrorAction SilentlyContinue
        foreach ($resolvedEntry in $resolvedEntries) {
            $null = $candidateDirectories.Add($resolvedEntry.Path)
        }
    }

    $rootHints = @($env:TEXDIR, $env:TEXLIVE_HOME, $env:TLROOT)
    foreach ($hint in $rootHints) {
        if (-not [string]::IsNullOrWhiteSpace($hint) -and (Test-Path $hint)) {
            $resolvedHint = Resolve-Path -Path $hint -ErrorAction SilentlyContinue
            foreach ($item in $resolvedHint) {
                $null = $searchRoots.Add($item.Path)
                $null = $candidateDirectories.Add($item.Path)
                foreach ($suffix in @('bin', 'bin\win32', 'bin\windows')) {
                    $candidate = Join-Path $item.Path $suffix
                    if (-not (Test-Path $candidate)) { continue }
                    $resolvedCandidate = Resolve-Path -Path $candidate -ErrorAction SilentlyContinue
                    foreach ($resolvedItem in $resolvedCandidate) {
                        $null = $candidateDirectories.Add($resolvedItem.Path)
                    }
                }
            }
        }
    }

    $defaultRoots = @()
    if (-not [string]::IsNullOrWhiteSpace($env:SystemDrive)) {
        $defaultRoots += (Join-Path $env:SystemDrive 'texlive')
    }
    if (-not [string]::IsNullOrWhiteSpace($env:ProgramFiles)) {
        $defaultRoots += (Join-Path $env:ProgramFiles 'texlive')
        $defaultRoots += (Join-Path $env:ProgramFiles 'TeXLive')
    }

    foreach ($root in $defaultRoots) {
        if (-not (Test-Path $root)) { continue }
        $resolvedRoot = Resolve-Path -Path $root -ErrorAction SilentlyContinue
        foreach ($item in $resolvedRoot) {
            $null = $searchRoots.Add($item.Path)
            $null = $candidateDirectories.Add($item.Path)
            foreach ($suffix in @('bin', 'bin\win32', 'bin\windows')) {
                $candidate = Join-Path $item.Path $suffix
                if (-not (Test-Path $candidate)) { continue }
                $resolvedCandidate = Resolve-Path -Path $candidate -ErrorAction SilentlyContinue
                foreach ($resolvedItem in $resolvedCandidate) {
                    $null = $candidateDirectories.Add($resolvedItem.Path)
                }
            }
        }

        $subDirectories = Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue
        foreach ($subDir in $subDirectories) {
            $null = $candidateDirectories.Add($subDir.FullName)
            foreach ($suffix in @('bin', 'bin\win32', 'bin\windows')) {
                $candidate = Join-Path $subDir.FullName $suffix
                if (-not (Test-Path $candidate)) { continue }
                $resolvedCandidate = Resolve-Path -Path $candidate -ErrorAction SilentlyContinue
                foreach ($item in $resolvedCandidate) {
                    $null = $candidateDirectories.Add($item.Path)
                }
            }
        }
    }

    foreach ($directory in $candidateDirectories) {
        foreach ($candidateName in @('tlmgr.bat', 'tlmgr.exe')) {
            $candidatePath = Join-Path $directory $candidateName
            if (Test-Path $candidatePath) {
                return $candidatePath
            }
        }
    }

    foreach ($root in $searchRoots) {
        if (-not (Test-Path $root)) { continue }
        $fallback = Get-ChildItem -Path $root -Include 'tlmgr.bat', 'tlmgr.exe' -Recurse -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($fallback) {
            return $fallback.FullName
        }
    }

    return $null
}

function Get-LaTeXPackageManager {
    $tlmgrPath = Find-TlmgrExecutable
    if ($tlmgrPath) {
        return @{ Type = 'TeXLive'; Path = $tlmgrPath }
    }

    $mpm = Get-Command 'mpm' -ErrorAction SilentlyContinue
    if (-not $mpm) {
        $mpm = Get-Command 'mpm.exe' -ErrorAction SilentlyContinue
    }
    if (-not $mpm) {
        $miktexRoots = @()
        if ($env:ProgramFiles) { $miktexRoots += (Join-Path $env:ProgramFiles 'MiKTeX\miktex\bin\x64') }
        if ($env:ProgramFiles) { $miktexRoots += (Join-Path $env:ProgramFiles 'MiKTeX\miktex\bin') }
        if (${env:ProgramFiles(x86)}) { $miktexRoots += (Join-Path ${env:ProgramFiles(x86)} 'MiKTeX\miktex\bin\x64') }
        if (${env:ProgramFiles(x86)}) { $miktexRoots += (Join-Path ${env:ProgramFiles(x86)} 'MiKTeX\miktex\bin') }
        foreach ($root in $miktexRoots) {
            $candidate = Join-Path $root 'mpm.exe'
            if (Test-Path $candidate) {
                $mpm = $candidate
                break
            }
        }
    }

    if ($mpm) {
        $mpmPath = if ($mpm -is [string]) { $mpm } else { $mpm.Path }
        return @{ Type = 'MiKTeX'; Path = $mpmPath }
    }

    return $null
}

function Resolve-LaTeXMissingPackages {
    param(
        [Parameter(Mandatory = $true)][string]$LogPath
    )

    if (-not (Test-Path $LogPath)) {
        return $false
    }

    $logContent = Get-Content -Path $LogPath -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $logContent) {
        return $false
    }

    $pattern = "LaTeX Error: File `([^']+)' not found."
    $matches = [regex]::Matches($logContent, $pattern)
    if ($matches.Count -eq 0) {
        return $false
    }

    $fileToPackageMap = @{
        'abnt.cls'              = 'abntex2'
        'abntex-abrev.sty'      = 'abntex2'
        'abntex-default-design.sty' = 'abntex2'
        'bigintcalc.sty'        = 'bigintcalc'
        'bitset.sty'            = 'bitset'
        'breakurl.sty'          = 'breakurl'
        'caption.sty'           = 'caption'
        'caption3.sty'          = 'caption'
        'chngcntr.sty'          = 'chngcntr'
        'etoolbox.sty'          = 'etoolbox'
        'float.sty'             = 'float'
        'gettitlestring.sty'    = 'gettitlestring'
        'hycolor.sty'           = 'hycolor'
        'ifluatex.sty'          = 'ifluatex'
        'ifpdf.sty'             = 'ifpdf'
        'iftex.sty'             = 'iftex'
        'ifxetex.sty'           = 'ifxetex'
        'infwarerr.sty'         = 'oberdiek'
        'kvdefinekeys.sty'      = 'kvdefinekeys'
        'kvoptions.sty'         = 'kvoptions'
        'kvsetkeys.sty'         = 'kvsetkeys'
        'lastpage.sty'          = 'lastpage'
        'lastpage2e.sty'        = 'lastpage'
        'lastpagemodern.sty'    = 'lastpage'
        'ltxcmds.sty'           = 'ltxcmds'
        'nameref.sty'           = 'hyperref'
        'newfloat.sty'          = 'newfloat'
        'intcalc.sty'           = 'intcalc'
        'pdfescape.sty'         = 'pdfescape'
        'pdftexcmds.sty'        = 'pdftexcmds'
        'pdfpages.sty'          = 'pdfpages'
        'graphicx.sty'          = 'graphics'
        'graphics.sty'          = 'graphics'
        'color.sty'             = 'graphics'
        'xcolor.sty'            = 'xcolor'
        'fancyhdr.sty'          = 'fancyhdr'
        'multirow.sty'          = 'multirow'
        'tabularx.sty'          = 'tabularx'
        'longtable.sty'         = 'longtable'
        'perpage.sty'           = 'bigfoot'
        'rerunfilecheck.sty'    = 'rerunfilecheck'
        'stringenc.sty'         = 'stringenc'
        'uniquecounter.sty'     = 'uniquecounter'
        'url.sty'               = 'url'
        'xkeyval.sty'           = 'xkeyval'
    }

    $packages = New-Object System.Collections.Generic.List[string]
    foreach ($match in $matches) {
        $rawFileName = $match.Groups[1].Value
        $fileName = ($rawFileName -split '[\\/]')[-1]
        if ($fileToPackageMap.ContainsKey($fileName)) {
            $packageName = $fileToPackageMap[$fileName]
        } else {
            $packageName = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
        }

        if ([string]::IsNullOrWhiteSpace($packageName)) {
            continue
        }

        if ($packageName -notmatch '^[A-Za-z0-9\-]+$') {
            continue
        }

        if (-not $packages.Contains($packageName)) {
            $packages.Add($packageName) | Out-Null
        }
    }

    if ($packages.Count -eq 0) {
        return $false
    }

    $packagesArray = $packages.ToArray()

    $packageManager = Get-LaTeXPackageManager
    if (-not $packageManager) {
        $packagesList = [string]::Join(', ', $packagesArray)
        Write-Warning ("Pacotes ausentes detectados ({0}). Instale-os manualmente para prosseguir." -f $packagesList)
        return $false
    }
    Write-Host "\n>>> Instalando automaticamente os pacotes LaTeX ausentes: $([string]::Join(', ', $packagesArray))..." -ForegroundColor Cyan

    switch ($packageManager.Type) {
        'TeXLive' {
            $output = & $packageManager.Path 'install' @packagesArray 2>&1
            $exitCode = [int]$LASTEXITCODE
            if ($exitCode -ne 0) {
                Write-Verbose ("tlmgr retornou código {0} na instalação padrão. Tentando modo usuário." -f $exitCode)
                $outputUser = & $packageManager.Path '--usermode' 'install' @packagesArray 2>&1
                $exitCode = [int]$LASTEXITCODE
                if ($exitCode -ne 0) {
                    Write-Warning 'Falha ao instalar os pacotes ausentes com tlmgr (modo padrão e usuário).'
                    Write-Verbose $output
                    Write-Verbose $outputUser
                    return $false
                }
            }
        }
        'MiKTeX' {
            $arguments = "--install=$([string]::Join(',', $packagesArray))"
            $output = & $packageManager.Path '--admin' $arguments 2>&1
            $exitCode = [int]$LASTEXITCODE
            if ($exitCode -ne 0) {
                Write-Verbose ("mpm retornou código {0} com --admin. Tentando modo usuário." -f $exitCode)
                $outputUser = & $packageManager.Path $arguments 2>&1
                $exitCode = [int]$LASTEXITCODE
                if ($exitCode -ne 0) {
                    Write-Warning 'Falha ao instalar os pacotes ausentes com mpm (--admin e usuário).'
                    Write-Verbose $output
                    Write-Verbose $outputUser
                    return $false
                }
            }
        }
        default {
            Write-Warning 'Gerenciador de pacotes LaTeX não suportado para instalação automática.'
            return $false
        }
    }

    return $true
}

Push-Location $workingDirectory
try {
    if ($Clean) {
        if ($latexmkPath) {
            Write-Host "\n>>> Limpando arquivos temporários com latexmk..." -ForegroundColor Cyan
            & $latexmkPath -C $texFile | Out-Null
        } else {
            Write-Host "\n>>> Limpando arquivos temporários manualmente..." -ForegroundColor Cyan
            $extensions = @('aux','bbl','blg','brf','idx','ilg','ind','ist','lof','log','lot','out','toc','synctex.gz')
            foreach ($ext in $extensions) {
                $target = "${baseName}.$ext"
                if (Test-Path $target) { Remove-Item $target -Force }
            }
        }
    }

    $latexmkSucceeded = $false
    if ($latexmkPath) {
        Write-Host "\n>>> Compilando com latexmk ($Engine) para garantir conformidade ABNT..." -ForegroundColor Green
        $latexmkBaseArgs = switch ($Engine) {
            'pdflatex' { @('-pdf', "-pdflatex=$Engine -interaction=nonstopmode -synctex=1") }
            'xelatex' { @('-xelatex', "-xelatex=$Engine -interaction=nonstopmode -synctex=1") }
            'lualatex' { @('-lualatex', "-lualatex=$Engine -interaction=nonstopmode -synctex=1") }
        }
        $latexmkBaseArgs += $texFile

        & $latexmkPath @latexmkBaseArgs
        $latexmkExitCode = [int]$LASTEXITCODE
        if ($latexmkExitCode -eq 0) {
            $latexmkSucceeded = $true
        } else {
            Write-Warning ("latexmk retornou o código {0}. Tentando reconstrução completa." -f $latexmkExitCode)
            if (-not $Clean) {
                Write-Host "\n>>> Forçando limpeza de artefatos antes da nova tentativa..." -ForegroundColor Yellow
                & $latexmkPath -C $texFile | Out-Null
            }
            & $latexmkPath -gg @latexmkBaseArgs
            $latexmkExitCode = [int]$LASTEXITCODE
            if ($latexmkExitCode -eq 0) {
                $latexmkSucceeded = $true
            } else {
                Write-Warning ("latexmk falhou novamente (código {0}). Iniciando fallback manual." -f $latexmkExitCode)
            }
        }
    }

    if (-not $latexmkSucceeded) {
        $logPath = Join-Path (Get-Location) ("${baseName}.log")
        $packagesInstalled = Resolve-LaTeXMissingPackages -LogPath $logPath
        if ($packagesInstalled -and $latexmkPath) {
            Write-Host "\n>>> Pacotes instalados. Reexecutando latexmk ($Engine)..." -ForegroundColor Cyan
            & $latexmkPath @latexmkBaseArgs
            $latexmkExitCode = [int]$LASTEXITCODE
            if ($latexmkExitCode -eq 0) {
                $latexmkSucceeded = $true
            }
        }
    }

    if (-not $latexmkSucceeded) {
        if (-not $latexmkPath) {
            Write-Host "\n>>> latexmk não encontrado. Executando sequência manual ($Engine + bibtex)..." -ForegroundColor Yellow
        } else {
            Write-Host "\n>>> Executando sequência manual ($Engine + bibtex) para concluir a compilação..." -ForegroundColor Yellow
        }
        $pdflatexArgs = @('-interaction=nonstopmode', '-synctex=1', $texFile)
        & $enginePath @pdflatexArgs | Out-Null
        if ($bibtexPath) {
            & $bibtexPath $baseName | Out-Null
        } else {
            Write-Warning 'bibtex não encontrado. As referências ABNT podem não ser atualizadas corretamente.'
        }
        & $enginePath @pdflatexArgs | Out-Null
        & $enginePath @pdflatexArgs
    }

    $pdfPath = Join-Path (Get-Location) ("${baseName}.pdf")
    if (Test-Path $pdfPath) {
        Write-Host "\nPDF gerado em: $pdfPath" -ForegroundColor Green
    } else {
        throw 'O PDF não foi localizado após a compilação. Verifique o log para diagnosticar problemas.'
    }
}
finally {
    Pop-Location
}
