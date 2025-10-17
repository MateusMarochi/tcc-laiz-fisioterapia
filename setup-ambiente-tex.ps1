<#
.SYNOPSIS
    Prepara um ambiente Windows para compilar o TCC em LaTeX conforme normas ABNT.
.DESCRIPTION
    Verifica pré-requisitos, instala dependências via winget ou Chocolatey e valida ferramentas essenciais
    (pdflatex, latexmk, bibtex, makeindex e Ghostscript). Utiliza mensagens coloridas e emojis para orientar o usuário.
.NOTES
    Execute em um console do Windows PowerShell 5.1 ou superior com privilégios administrativos.
#>
[CmdletBinding()]
param(
    [switch]$ForcarChocolatey
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Write-Info {
    param([string]$Mensagem)
    Write-Host "ℹ️  $Mensagem" -ForegroundColor Cyan
}

function Write-Sucesso {
    param([string]$Mensagem)
    Write-Host "✅ $Mensagem" -ForegroundColor Green
}

function Write-Alerta {
    param([string]$Mensagem)
    Write-Host "⚠️  $Mensagem" -ForegroundColor Yellow
}

function Write-Erro {
    param([string]$Mensagem)
    Write-Host "❌ $Mensagem" -ForegroundColor Red
}

if (-not $IsWindows) {
    Write-Erro 'Este script foi projetado exclusivamente para Windows. Utilize o ambiente adequado.'
    exit 1
}

$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Erro 'É necessário executar o PowerShell como Administrador para instalar as dependências.'
    exit 1
}

Write-Info 'Garantindo que o protocolo TLS moderno esteja habilitado para downloads seguros.'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Teste-Comando {
    param([string]$Nome)
    return [bool](Get-Command -Name $Nome -ErrorAction SilentlyContinue)
}

function Instalar-Chocolatey {
    Write-Info 'Instalando o Chocolatey para gerenciar pacotes, conforme as melhores práticas de ambientes científicos.'
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    Write-Sucesso 'Chocolatey instalado com sucesso.'
}

function Obter-GerenciadorPacotes {
    if (-not $ForcarChocolatey -and (Teste-Comando 'winget')) {
        Write-Sucesso 'Winget encontrado: será utilizado como gerenciador principal.'
        return 'winget'
    }

    if (Teste-Comando 'choco') {
        Write-Sucesso 'Chocolatey encontrado: será utilizado para instalar os pacotes.'
        return 'choco'
    }

    Write-Alerta 'Nenhum gerenciador encontrado. O script instalará o Chocolatey automaticamente.'
    Instalar-Chocolatey
    return 'choco'
}

$gerenciador = Obter-GerenciadorPacotes

function Instalar-Pacote {
    param(
        [string]$NomeApresentacao,
        [string]$WingetId,
        [string]$ChocolateyId,
        [string[]]$ComandosValidacao
    )

    $instalado = $true
    foreach ($cmd in $ComandosValidacao) {
        if (-not (Teste-Comando $cmd)) {
            $instalado = $false
            break
        }
    }

    if ($instalado) {
        Write-Sucesso "$NomeApresentacao já está configurado."
        return
    }

    Write-Info "Instalando $NomeApresentacao..."
    switch ($gerenciador) {
        'winget' {
            $argumentos = @('install', '--exact', '--id', $WingetId, '--accept-package-agreements', '--accept-source-agreements')
            Start-Process -FilePath 'winget' -ArgumentList $argumentos -Wait -NoNewWindow
        }
        'choco' {
            $argumentos = @('install', $ChocolateyId, '-y')
            Start-Process -FilePath 'choco' -ArgumentList $argumentos -Wait -NoNewWindow
        }
    }

    foreach ($cmd in $ComandosValidacao) {
        if (-not (Teste-Comando $cmd)) {
            Write-Erro "Falha ao validar a instalação de $NomeApresentacao. Verifique manualmente."
            throw "Dependência não encontrada: $cmd"
        }
    }
    Write-Sucesso "$NomeApresentacao instalado e validado."
}

Write-Info 'Iniciando instalação das ferramentas LaTeX essenciais para o TCC em conformidade com a ABNT.'

$dependencias = @(
    @{ Nome = 'TeX Live (distribuição LaTeX completa)'; Winget = 'TeXLive.TeXLive'; Choco = 'texlive-full'; Validacao = @('pdflatex', 'bibtex', 'latexmk', 'makeindex') },
    @{ Nome = 'Strawberry Perl (suporte ao latexmk)'; Winget = 'StrawberryPerl.StrawberryPerl'; Choco = 'strawberryperl'; Validacao = @('perl') },
    @{ Nome = 'Ghostscript (suporte a figuras EPS e conversões)'; Winget = 'ArtifexSoftware.GhostScript'; Choco = 'ghostscript'; Validacao = @('gswin64c', 'gswin32c') }
)

foreach ($dep in $dependencias) {
    try {
        Instalar-Pacote -NomeApresentacao $dep.Nome -WingetId $dep.Winget -ChocolateyId $dep.Choco -ComandosValidacao $dep.Validacao
    }
    catch {
        Write-Erro $_.Exception.Message
        throw
    }
}

Write-Info 'Ajustando a variável PATH do usuário para garantir acesso aos executáveis do TeX Live.'
$texBin = 'C:\\texlive\\2023\\bin\\windows'
if (Test-Path $texBin) {
    $pathAtual = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not $pathAtual.Split(';') -contains $texBin) {
        [Environment]::SetEnvironmentVariable('Path', ($pathAtual + ';' + $texBin).Trim(';'), 'User')
        Write-Sucesso "Caminho $texBin adicionado ao PATH do usuário."
    }
    else {
        Write-Info 'PATH já contém o diretório do TeX Live.'
    }
}
else {
    Write-Alerta 'Não foi possível localizar o diretório padrão do TeX Live. Caso tenha escolhido outro local, inclua-o manualmente no PATH.'
}

Write-Info 'Validando ferramentas críticas para compilar conforme as normas NBR 14724, NBR 6023 e NBR 10520.'
$comandosCriticos = @('pdflatex', 'latexmk', 'bibtex', 'makeindex', 'perl')
$falhas = @()
foreach ($cmd in $comandosCriticos) {
    if (-not (Teste-Comando $cmd)) {
        $falhas += $cmd
    }
}

if ($falhas.Count -gt 0) {
    Write-Erro "As seguintes ferramentas ainda não foram encontradas: $($falhas -join ', ')."
    Write-Erro 'Revise as instalações acima e tente novamente para garantir a conformidade total com o fluxo ABNT.'
    exit 1
}

Write-Sucesso 'Ambiente configurado! Você já pode compilar o TCC localmente com suporte total às normas ABNT.'
Write-Info 'Reinicie o terminal para carregar as novas variáveis de ambiente antes de iniciar a compilação.'
