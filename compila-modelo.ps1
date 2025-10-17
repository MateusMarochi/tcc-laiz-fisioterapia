<#
.SYNOPSIS
    Compila o arquivo modelo.tex gerando o PDF final conforme o fluxo ABNT recomendado.
.DESCRIPTION
    Limpa arquivos auxiliares, executa pdflatex, makeindex e bibtex em sequência controlada e repete compilações
    quando necessário para garantir consistência de referências, índices e listas.
.NOTES
    Execute após configurar o ambiente com setup-ambiente-tex.ps1.
#>
[CmdletBinding()]
param(
    [string]$Arquivo = 'modelo.tex'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Write-Info {
    param([string]$Mensagem)
    Write-Host "ℹ️  $Mensagem" -ForegroundColor Cyan
}

function Write-Sucesso {
    param([string]$Mensagem)
    Write-Host "🎉 $Mensagem" -ForegroundColor Green
}

function Write-Alerta {
    param([string]$Mensagem)
    Write-Host "⚠️  $Mensagem" -ForegroundColor Yellow
}

function Write-Erro {
    param([string]$Mensagem)
    Write-Host "❌ $Mensagem" -ForegroundColor Red
}

function Teste-Comando {
    param([string]$Nome)
    return [bool](Get-Command -Name $Nome -ErrorAction SilentlyContinue)
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $scriptDir) {
    $scriptDir = Get-Location
}
Set-Location $scriptDir

if (-not (Test-Path $Arquivo)) {
    Write-Erro "Não foi possível localizar o arquivo $Arquivo neste diretório."
    exit 1
}

Write-Info 'Verificando disponibilidade das ferramentas essenciais (pdflatex, bibtex, makeindex).'
$necessarios = @('pdflatex', 'bibtex', 'makeindex')
foreach ($cmd in $necessarios) {
    if (-not (Teste-Comando $cmd)) {
        Write-Erro "O comando $cmd não foi encontrado no PATH. Execute setup-ambiente-tex.ps1 antes de prosseguir."
        exit 1
    }
}

$arquivoBase = [System.IO.Path]::GetFileNameWithoutExtension($Arquivo)
$log = "$arquivoBase.log"
$cleanExtensoes = 'aux','toc','idx','ind','ilg','log','out','brf','blg','bbl','lot','lof','lsb','lsg','synctex.gz','nav','snm','fls','fdb_latexmk','auxlock','run.xml','bcf'

Write-Info 'Limpando arquivos auxiliares antigos para evitar conflitos de compilação.'
foreach ($ext in $cleanExtensoes) {
    Get-ChildItem -Filter "*.$ext" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
}

function Executar-Comando {
    param(
        [string]$Comando,
        [string]$Argumentos,
        [string]$Descricao
    )
    Write-Info "$Descricao"
    $processo = Start-Process -FilePath $Comando -ArgumentList $Argumentos -NoNewWindow -PassThru -Wait
    if ($processo.ExitCode -ne 0) {
        Write-Erro "Falha ao executar $Comando. Revise o log para detalhes."
        throw "Erro no comando $Comando"
    }
}

function Necessita-Recompilar {
    param([string]$LogPath)
    if (-not (Test-Path $LogPath)) { return $false }
    $conteudo = Get-Content $LogPath -Raw -ErrorAction SilentlyContinue
    return ($conteudo -match 'Rerun LaTeX' -or $conteudo -match 'Rerun to get cross-references right')
}

function Atualizar-ListaSiglas {
    param([string]$ArquivoSiglas)
    if (Test-Path $ArquivoSiglas) {
        Write-Info 'Ordenando tabela de siglas para manter conformidade com a NBR 14724.'
        $conteudo = Get-Content $ArquivoSiglas | Sort-Object
        $temporario = "{0}2.lsg" -f $arquivoBase
        Set-Content -Path $temporario -Value $conteudo -Encoding UTF8
        Move-Item -Path $temporario -Destination $ArquivoSiglas -Force
    }
}

Write-Info 'Executando a primeira compilação LaTeX.'
Executar-Comando -Comando 'pdflatex' -Argumentos "-interaction=nonstopmode -synctex=1 $Arquivo" -Descricao '1ª rodada do pdflatex (estrutura básica)'

Write-Info 'Atualizando índice remissivo logo após a primeira compilação.'
$possuiIndice = Test-Path "$arquivoBase.idx"
if ($possuiIndice) {
    Executar-Comando -Comando 'makeindex' -Argumentos "$arquivoBase.idx" -Descricao 'Processando índice remissivo'
}
else {
    Write-Alerta 'Índice remissivo não encontrado; etapa ignorada (caso não utilize índice, este aviso é esperado).'
}

Write-Info 'Rodada adicional do pdflatex para consolidar a estrutura inicial.'
Executar-Comando -Comando 'pdflatex' -Argumentos "-interaction=nonstopmode -synctex=1 $Arquivo" -Descricao '2ª rodada do pdflatex'

$tentativas = 0
while ((Necessita-Recompilar -LogPath $log) -and $tentativas -lt 5) {
    $tentativas++
    Write-Alerta "Referências atualizadas requerem nova compilação (tentativa $tentativas)."
    Executar-Comando -Comando 'pdflatex' -Argumentos "-interaction=nonstopmode -synctex=1 $Arquivo" -Descricao "Rodada extra do pdflatex ($tentativas)"
}

if ($tentativas -ge 5 -and (Necessita-Recompilar -LogPath $log)) {
    Write-Alerta 'Ainda há avisos de recompilação após várias tentativas. Revise o arquivo .log para detalhes.'
}

if ($possuiIndice) {
    Executar-Comando -Comando 'makeindex' -Argumentos "$arquivoBase.idx" -Descricao 'Atualizando índice após ajustes de referências'
}

Write-Info 'Processando referências bibliográficas conforme a NBR 6023.'
Executar-Comando -Comando 'bibtex' -Argumentos $arquivoBase -Descricao '1ª rodada do bibtex'

Write-Info 'Incorporando bibliografia à estrutura do documento.'
Executar-Comando -Comando 'pdflatex' -Argumentos "-interaction=nonstopmode -synctex=1 $Arquivo" -Descricao '3ª rodada do pdflatex'

Executar-Comando -Comando 'bibtex' -Argumentos $arquivoBase -Descricao '2ª rodada do bibtex'

Write-Info 'Executando compilação adicional para estabilizar citações e listas.'
Executar-Comando -Comando 'pdflatex' -Argumentos "-interaction=nonstopmode -synctex=1 $Arquivo" -Descricao '4ª rodada do pdflatex'

if (Test-Path "$arquivoBase.lsg") {
    Atualizar-ListaSiglas -ArquivoSiglas "$arquivoBase.lsg"
}

Write-Info 'Compilação final para garantir listas e anexos atualizados.'
Executar-Comando -Comando 'pdflatex' -Argumentos "-interaction=nonstopmode -synctex=1 $Arquivo" -Descricao 'Compilação final do pdflatex'

if (Test-Path "$arquivoBase.pdf") {
    Write-Sucesso "PDF gerado com sucesso: $arquivoBase.pdf"
}
else {
    Write-Alerta 'O PDF não foi encontrado no diretório atual. Verifique o log para identificar possíveis problemas.'
}

Write-Info 'Processo concluído. Verifique capas, listas e citações conforme as normas NBR 14724, NBR 6023 e NBR 10520.'
