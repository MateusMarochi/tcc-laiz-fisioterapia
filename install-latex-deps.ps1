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
    $candidateRoots = @(
        (Join-Path $env:SystemDrive 'texlive'),
        (Join-Path $env:ProgramFiles 'texlive')
    )

    foreach ($root in $candidateRoots) {
        if (Test-Path $root) {
            $tlmgr = Get-ChildItem -Path $root -Filter 'tlmgr.bat' -Recurse -ErrorAction SilentlyContinue |
                Sort-Object FullName -Descending |
                Select-Object -First 1
            if ($tlmgr) {
                return $tlmgr.FullName
            }
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
        newfloat caption float xkeyval kvoptions kvsetkeys kvdefinekeys ifpdf iftex etoolbox hycolor stringenc breakurl
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
    & $mpm --admin --install=abntex2,latexmk,xindy,texcount,newfloat,caption,float,xkeyval,kvoptions,kvsetkeys,kvdefinekeys,ifpdf,iftex,etoolbox,hycolor,stringenc,breakurl

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
