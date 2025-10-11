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

function Get-LaTeXPackageManager {
    $tlmgr = Get-Command 'tlmgr' -ErrorAction SilentlyContinue
    if ($tlmgr) {
        return @{ Type = 'TeXLive'; Path = $tlmgr.Path }
    }

    $mpm = Get-Command 'mpm' -ErrorAction SilentlyContinue
    if (-not $mpm) {
        $mpm = Get-Command 'mpm.exe' -ErrorAction SilentlyContinue
    }

    if ($mpm) {
        return @{ Type = 'MiKTeX'; Path = $mpm.Path }
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
        'newfloat.sty' = 'newfloat'
        'caption.sty'  = 'caption'
        'float.sty'    = 'float'
    }

    $packages = @()
    foreach ($match in $matches) {
        $fileName = $match.Groups[1].Value
        if ($fileToPackageMap.ContainsKey($fileName) -and $packages -notcontains $fileToPackageMap[$fileName]) {
            $packages += $fileToPackageMap[$fileName]
        }
    }

    if ($packages.Count -eq 0) {
        return $false
    }

    $packageManager = Get-LaTeXPackageManager
    if (-not $packageManager) {
        Write-Warning "Pacotes ausentes detectados ($($packages -join ', ')). Instale-os manualmente para prosseguir."
        return $false
    }

    Write-Host "\n>>> Instalando automaticamente os pacotes LaTeX ausentes: $($packages -join ', ')..." -ForegroundColor Cyan

    switch ($packageManager.Type) {
        'TeXLive' {
            & $packageManager.Path 'install' @packages | Out-Null
        }
        'MiKTeX' {
            & $packageManager.Path '--admin' "--install=$([string]::Join(',', $packages))" | Out-Null
        }
        default {
            Write-Warning 'Gerenciador de pacotes LaTeX não suportado para instalação automática.'
            return $false
        }
    }

    if ($LASTEXITCODE -ne 0) {
        Write-Warning 'Falha ao instalar os pacotes ausentes. Verifique manualmente a distribuição LaTeX.'
        return $false
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
            Write-Warning "latexmk retornou o código $latexmkExitCode. Tentando reconstrução completa."
            if (-not $Clean) {
                Write-Host "\n>>> Forçando limpeza de artefatos antes da nova tentativa..." -ForegroundColor Yellow
                & $latexmkPath -C $texFile | Out-Null
            }
            & $latexmkPath -gg @latexmkBaseArgs
            $latexmkExitCode = [int]$LASTEXITCODE
            if ($latexmkExitCode -eq 0) {
                $latexmkSucceeded = $true
            } else {
                Write-Warning "latexmk falhou novamente (código $latexmkExitCode). Iniciando fallback manual."
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
