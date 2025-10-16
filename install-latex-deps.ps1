<#
.SYNOPSIS
    Script para instalar dependências necessárias à compilação do TCC em LaTeX no Windows.

.DESCRIPTION
    Este script PowerShell instala automaticamente uma distribuição LaTeX completa, utilitários de suporte e os
    pacotes indispensáveis às normas ABNT (NBR 14724, NBR 6023, NBR 10520 e correlatas). Por padrão, utiliza o TeX Live,
    mas permite selecionar o MiKTeX. São instalados ainda componentes auxiliares para garantir o correto funcionamento
    do latexmk e a compatibilidade com arquivos EPS presentes no modelo.

.PARAMETER Distribution
    Define a distribuição LaTeX a ser instalada. Valores aceitos: "texlive" (padrão) ou "miktex".

.EXAMPLE
    .\install-latex-deps.ps1
    Executa a instalação padrão com TeX Live.

.EXAMPLE
    .\install-latex-deps.ps1 -Distribution miktex
    Instala o MiKTeX e configura os pacotes ABNT correspondentes.

.NOTES
    Execute este script em um PowerShell com privilégios administrativos. É recomendável fechar editores LaTeX antes
    de iniciar o processo. Após a conclusão, reinicie o terminal para recarregar variáveis de ambiente.
#>

[CmdletBinding()]
param(
    [ValidateSet('texlive', 'miktex')]
    [string]$Distribution = 'texlive',
    [switch]$ForceReinstall
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
} catch {
    Write-Verbose 'Não foi possível ajustar a codificação do console para UTF-8.'
}

function Test-Administrator {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Administrator)) {
    throw 'Este script deve ser executado com privilégios administrativos.'
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw 'A ferramenta winget não foi localizada. Instale o App Installer da Microsoft Store e tente novamente.'
}

function Install-PackageWinget {
    param(
        [Parameter(Mandatory = $true)][string]$Id,
        [string]$CustomName
    )

    $name = if ($CustomName) { $CustomName } else { $Id }
    $alreadyInstalled = $false
    if (-not $ForceReinstall) {
        $listOutput = winget list --id $Id --exact --source winget 2>$null
        if ($LASTEXITCODE -eq 0 -and $listOutput -match [regex]::Escape($Id)) {
            $alreadyInstalled = $true
        }
    }

    if ($alreadyInstalled -and -not $ForceReinstall) {
        Write-Host "\n>>> $name já instalado. Utilize -ForceReinstall para reinstalar." -ForegroundColor Yellow
        return
    }

    Write-Host "\n>>> Instalando $name via winget..." -ForegroundColor Cyan
    $arguments = @(
        'install',
        '--id', $Id,
        '--exact',
        '--source', 'winget',
        '--accept-package-agreements',
        '--accept-source-agreements'
    )
    if ($ForceReinstall) {
        $arguments += '--force'
    }
    winget @arguments | Out-Null
}

function Get-TlmgrPath {
    $commandNames = @('tlmgr.bat', 'tlmgr.exe', 'tlmgr')
    foreach ($name in $commandNames) {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($command) {
            return $command.Path
        }
    }

    $pathEntries = $env:PATH -split ';'
    foreach ($entry in $pathEntries) {
        if ([string]::IsNullOrWhiteSpace($entry)) { continue }
        if ($entry -notlike '*texlive*') { continue }
        $resolvedEntries = Resolve-Path -Path $entry -ErrorAction SilentlyContinue
        foreach ($resolvedEntry in $resolvedEntries) {
            foreach ($candidateName in @('tlmgr.bat', 'tlmgr.exe')) {
                $candidatePath = Join-Path $resolvedEntry.Path $candidateName
                if (Test-Path $candidatePath) {
                    return $candidatePath
                }
            }
        }
    }

    $rootCandidates = New-Object System.Collections.Generic.List[string]
    foreach ($value in @($env:TEXDIR, $env:TEXLIVE_HOME, $env:TLROOT)) {
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            $rootCandidates.Add($value) | Out-Null
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
        if (-not $rootCandidates.Contains($root)) {
            $rootCandidates.Add($root) | Out-Null
        }
    }

    foreach ($root in $rootCandidates) {
        if (-not (Test-Path $root)) { continue }
        $resolvedRoot = Resolve-Path -Path $root -ErrorAction SilentlyContinue
        if (-not $resolvedRoot) { continue }

        $directories = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
        $null = $directories.Add($resolvedRoot.Path)

        foreach ($suffix in @('bin', 'bin\win32', 'bin\windows')) {
            $directChild = Join-Path $resolvedRoot.Path $suffix
            if (-not (Test-Path $directChild)) { continue }
            $resolvedChildren = Resolve-Path -Path $directChild -ErrorAction SilentlyContinue
            foreach ($resolvedChild in $resolvedChildren) {
                $null = $directories.Add($resolvedChild.Path)
            }
        }

        $subDirectories = Get-ChildItem -Path $resolvedRoot.Path -Directory -ErrorAction SilentlyContinue
        foreach ($subDir in $subDirectories) {
            $null = $directories.Add($subDir.FullName)
            foreach ($suffix in @('bin', 'bin\win32', 'bin\windows')) {
                $candidate = Join-Path $subDir.FullName $suffix
                if (-not (Test-Path $candidate)) { continue }
                $resolvedCandidates = Resolve-Path -Path $candidate -ErrorAction SilentlyContinue
                foreach ($resolvedCandidate in $resolvedCandidates) {
                    $null = $directories.Add($resolvedCandidate.Path)
                }
            }
        }

        foreach ($directory in $directories) {
            foreach ($candidateName in @('tlmgr.bat', 'tlmgr.exe')) {
                $candidatePath = Join-Path $directory $candidateName
                if (Test-Path $candidatePath) {
                    return $candidatePath
                }
            }
        }

        $fallback = Get-ChildItem -Path $resolvedRoot.Path -Include 'tlmgr.bat', 'tlmgr.exe' -Recurse -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($fallback) {
            return $fallback.FullName
        }
    }

    return $null
}

function Configure-TeXLive {
    Write-Host "\n>>> Configurando TeX Live (pacotes ABNT e utilitários)..." -ForegroundColor Cyan
    $tlmgrPath = Get-TlmgrPath
    if (-not $tlmgrPath) {
        throw 'tlmgr não foi localizado. Verifique se o TeX Live foi instalado corretamente.'
    }

    & $tlmgrPath option repository http://mirror.ctan.org/systems/texlive/tlnet | Out-Null
    & $tlmgrPath update --self --all
    & $tlmgrPath install abntex abntex2 collection-langportuguese latexmk xindy texcount `
        newfloat caption float chngcntr lastpage bigfoot xkeyval kvoptions kvsetkeys kvdefinekeys ifpdf iftex ifxetex ifluatex `
        etoolbox hycolor stringenc breakurl pdftexcmds pdfescape infwarerr ltxcmds gettitlestring rerunfilecheck uniquecounter `
        bigintcalc bitset intcalc url hyperref oberdiek pdfpages graphics xcolor fancyhdr multirow tabularx longtable
}

function Get-MiKTeXPath {
    $possiblePaths = @(
        (Join-Path $env:ProgramFiles 'MiKTeX\miktex\bin\x64'),
        (Join-Path $env:ProgramFiles 'MiKTeX\miktex\bin'),
        (Join-Path ${env:ProgramFiles(x86)} 'MiKTeX\miktex\bin\x64'),
        (Join-Path ${env:ProgramFiles(x86)} 'MiKTeX\miktex\bin')
    )

    foreach ($path in $possiblePaths) {
        if (Test-Path (Join-Path $path 'mpm.exe')) {
            return $path
        }
    }
    return $null
}

function Configure-MiKTeX {
    Write-Host "\n>>> Configurando MiKTeX (pacotes ABNT e utilitários)..." -ForegroundColor Cyan
    $miktexBin = Get-MiKTeXPath
    if (-not $miktexBin) {
        throw 'Ferramentas MiKTeX não foram localizadas. Confirme se a instalação foi concluída.'
    }

    $mpm = Join-Path $miktexBin 'mpm.exe'
    & $mpm --admin --update-db | Out-Null
    & $mpm --admin --upgrade | Out-Null
    & $mpm --admin --install=abntex2,latexmk,xindy,texcount,newfloat,caption,float,chngcntr,lastpage,bigfoot,xkeyval,kvoptions,kvsetkeys,kvdefinekeys,ifpdf,iftex,ifxetex,ifluatex,etoolbox,hycolor,stringenc,breakurl,pdftexcmds,pdfescape,infwarerr,ltxcmds,gettitlestring,rerunfilecheck,uniquecounter,bigintcalc,bitset,intcalc,url,hyperref,oberdiek,pdfpages,graphics,xcolor,fancyhdr,multirow,tabularx,longtable

    $initexmf = Join-Path $miktexBin 'initexmf.exe'
    if (Test-Path $initexmf) {
        & $initexmf --admin --update-fndb | Out-Null
    }
}

Write-Host "Iniciando instalação das dependências LaTeX para o TCC conforme normas ABNT..." -ForegroundColor Green

switch ($Distribution) {
    'texlive' {
        Install-PackageWinget -Id 'TeXLive.TeXLive' -CustomName 'TeX Live (distribuição completa)'
    }
    'miktex' {
        Install-PackageWinget -Id 'MiKTeX.MiKTeX' -CustomName 'MiKTeX'
        Install-PackageWinget -Id 'StrawberryPerl.StrawberryPerl' -CustomName 'Strawberry Perl (dependência do latexmk)'
    }
}

Install-PackageWinget -Id 'MiKTeX.Ghostscript' -CustomName 'Ghostscript (suporte a EPS/PDF)'
Install-PackageWinget -Id 'GnuWin32.Make' -CustomName 'GNU Make (suporte a scripts auxiliares)'

switch ($Distribution) {
    'texlive' { Configure-TeXLive }
    'miktex' { Configure-MiKTeX }
}

Write-Host "\nInstalação concluída. Reinicie o PowerShell para carregar as novas variáveis de ambiente." -ForegroundColor Green
Write-Host "Certifique-se de que o latexmk, pdflatex e bibtex estão acessíveis e de que a atualização das normas ABNT foi realizada." -ForegroundColor Green
