<#
    Script de compilação para gerar o PDF principal do TCC em Fisioterapia
    seguindo o fluxo pdflatex → bibtex → pdflatex → pdflatex, utilizando o
    latexmk para automatizar a reconstrução de índices, glossários e referências.
    Produz mensagens coloridas e lida com falhas comuns em ambiente Windows.
#>

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'

param(
    [string]$ArquivoPrincipal = 'main.tex'
)

function Mostrar-Cabecalho {
    Write-Host """════════════════════════════════════════════════════""" -ForegroundColor DarkMagenta
    Write-Host "  📄 Compilação do TCC em PDF - UTFPR Fisioterapia    " -ForegroundColor Magenta
    Write-Host """════════════════════════════════════════════════════""" -ForegroundColor DarkMagenta
}

function Validar-Ferramenta {
    param(
        [Parameter(Mandatory)][string]$Comando,
        [Parameter(Mandatory)][string]$Descricao
    )

    if (-not (Get-Command $Comando -ErrorAction SilentlyContinue)) {
        Write-Host "❌ $Descricao não encontrado(a). Execute o script 'Preparar-Ambiente.ps1' antes de compilar." -ForegroundColor Red
        exit 1
    }
}

function Obter-CaminhoRaiz {
    $scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    if ([string]::IsNullOrWhiteSpace($scriptPath)) {
        return (Get-Location).Path
    }
    return $scriptPath
}

Mostrar-Cabecalho
Validar-Ferramenta -Comando 'latexmk' -Descricao 'latexmk'
Validar-Ferramenta -Comando 'pdflatex' -Descricao 'pdflatex'
Validar-Ferramenta -Comando 'bibtex' -Descricao 'BibTeX'

$raiz = Obter-CaminhoRaiz
Set-Location $raiz

if (-not (Test-Path $ArquivoPrincipal)) {
    Write-Host "❌ Arquivo $ArquivoPrincipal não encontrado no diretório $raiz." -ForegroundColor Red
    exit 1
}

Write-Host "📂 Diretório de trabalho: $raiz" -ForegroundColor DarkCyan
Write-Host "🛠️ Iniciando latexmk para compilar $ArquivoPrincipal..." -ForegroundColor Cyan

try {
    latexmk -pdf -interaction=nonstopmode -file-line-error -synctex=1 -use-make $ArquivoPrincipal
    Write-Host "✅ PDF gerado com sucesso! Confira o arquivo correspondente na pasta." -ForegroundColor Green
}
catch {
    Write-Host "❌ Ocorreu um erro durante a compilação: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "🧹 Tentando limpeza de arquivos temporários e sugerindo nova execução..." -ForegroundColor Yellow
    latexmk -C $ArquivoPrincipal
    exit 1
}
finally {
    Write-Host """════════════════════════════════════════════════════""" -ForegroundColor DarkMagenta
    Write-Host "📚 A compilação utiliza normas ABNT com pacotes específicos já incluídos neste repositório." -ForegroundColor Magenta
    Write-Host """════════════════════════════════════════════════════""" -ForegroundColor DarkMagenta
}
