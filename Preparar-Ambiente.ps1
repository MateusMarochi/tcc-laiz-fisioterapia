<#
    Script de preparação do ambiente Windows para compilar os arquivos LaTeX
    do TCC em Fisioterapia seguindo as normas ABNT. Instala dependências via
    Chocolatey e valida os binários essenciais (pdflatex, bibtex, latexmk, makeindex,
    makeglossaries/texindy) garantindo suporte a arquivos .eps, listas de siglas
    e referências bibliográficas conforme o fluxo recomendado no repositório.
#>

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'

function Mostrar-Cabecalho {
    Write-Host """━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━""" -ForegroundColor DarkCyan
    Write-Host "  🚀 Preparação do Ambiente LaTeX - UTFPR Fisioterapia  " -ForegroundColor Cyan
    Write-Host """━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━""" -ForegroundColor DarkCyan
}

function Exigir-Administrador {
    $identidade = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identidade)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
        Write-Host "❌ É necessário executar este script em uma janela do PowerShell com privilégios administrativos." -ForegroundColor Red
        Write-Host "ℹ️ Clique com o botão direito no PowerShell e escolha 'Executar como administrador'." -ForegroundColor Yellow
        exit 1
    }
}

function Garantir-Tls12 {
    Write-Host "🔐 Garantindo uso de TLS 1.2 para downloads..." -ForegroundColor DarkCyan
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

function Garantir-Chocolatey {
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Host "🍫 Chocolatey já está instalado." -ForegroundColor Green
        return
    }

    Write-Host "🍫 Instalando Chocolatey..." -ForegroundColor Cyan
    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Write-Host "✅ Chocolatey instalado com sucesso!" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Falha ao instalar o Chocolatey: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

function Instalar-Pacote {
    param(
        [Parameter(Mandatory)][string]$Nome
    )

    Write-Host "📦 Verificando pacote $Nome..." -ForegroundColor DarkYellow
    if (choco list --local-only | Select-String -Pattern "^$Nome ") {
        Write-Host "✔️ $Nome já está instalado." -ForegroundColor Green
        return
    }

    try {
        Write-Host "⬇️ Instalando $Nome..." -ForegroundColor Cyan
        choco install $Nome -y --no-progress
        Write-Host "✅ $Nome instalado." -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Falha ao instalar ${Nome}: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

function Testar-Comando {
    param(
        [Parameter(Mandatory)][string]$Comando,
        [string]$Descricao
    )

    if (Get-Command $Comando -ErrorAction SilentlyContinue) {
        Write-Host "✨ $Descricao disponível ($Comando)." -ForegroundColor Green
    }
    else {
        Write-Host "⚠️ Não foi possível localizar $Descricao ($Comando). Verifique o PATH ou reinicie o terminal." -ForegroundColor Yellow
    }
}

Mostrar-Cabecalho
Exigir-Administrador
Garantir-Tls12
Garantir-Chocolatey

$pacotes = @(
    'texlive',         # Distribuição LaTeX completa com pacotes ABNT
    'strawberryperl',  # Necessário para latexmk e makeglossaries
    'ghostscript',     # Conversão de EPS para PDF (epstopdf)
    'git'              # Auxilia na sincronização do repositório
)

foreach ($pacote in $pacotes) {
    Instalar-Pacote -Nome $pacote
}

Write-Host "🔄 Atualizando TeX Live (tlmgr)..." -ForegroundColor Cyan
try {
    $texBin = Join-Path $env:ProgramFiles 'texlive\2023\bin\win32'
    if (-not (Test-Path $texBin)) {
        $texBin = Join-Path $env:ProgramFiles 'texlive\2024\bin\win32'
    }
    if (-not (Test-Path $texBin)) {
        $texBin = 'C:\texlive\2024\bin\win32'
    }
    if (Test-Path $texBin) {
        $env:Path = "$texBin;$env:Path"
        & tlmgr update --self --all --verify-repo=none | Out-String | ForEach-Object { $_ }
        Write-Host "✅ TeX Live atualizado." -ForegroundColor Green
    }
    else {
        Write-Host "⚠️ Diretório binário do TeX Live não localizado automaticamente. Abra uma nova sessão após a instalação para garantir o PATH correto." -ForegroundColor Yellow
    }
}
catch {
    Write-Host "⚠️ Não foi possível atualizar o TeX Live automaticamente: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host """━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━""" -ForegroundColor DarkCyan
Write-Host "📋 Validação dos comandos essenciais" -ForegroundColor Cyan
Write-Host """━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━""" -ForegroundColor DarkCyan

Testar-Comando -Comando 'pdflatex'      -Descricao 'pdflatex'
Testar-Comando -Comando 'latexmk'       -Descricao 'latexmk'
Testar-Comando -Comando 'bibtex'        -Descricao 'BibTeX'
Testar-Comando -Comando 'makeindex'     -Descricao 'MakeIndex'
Testar-Comando -Comando 'makeglossaries' -Descricao 'MakeGlossaries'
Testar-Comando -Comando 'tlmgr'         -Descricao 'Gerenciador TeX Live (tlmgr)'

Write-Host "🥳 Ambiente preparado! Feche e reabra o PowerShell para que todas as variáveis de ambiente sejam recarregadas." -ForegroundColor Green
Write-Host "📚 Agora é possível compilar o TCC com os scripts fornecidos mantendo a conformidade com as normas ABNT." -ForegroundColor Green
