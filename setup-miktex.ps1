<#
    Script: setup-miktex.ps1
    Objetivo: instalar e configurar o MiKTeX no Windows com modo "on-the-fly" habilitado
              e dependências necessárias para compilar o TCC deste repositório.
    Uso sugerido: executar em PowerShell elevado (Administrador).
#>
[CmdletBinding()]
param(
    [string]$RepositorioCTAN = "https://mirror.ctan.org/systems/win32/miktex/tm/packages/",
    [switch]$ForcarDownload
)

$emojis = [PSCustomObject]@{
    Info     = "ℹ️"
    Sucesso  = "✅"
    Erro     = "❌"
    Atenção  = "⚠️"
    Rodando  = "🚀"
}

function Escrever-Passo {
    param(
        [string]$Mensagem,
        [ConsoleColor]$Cor = 'Cyan'
    )
    Write-Host "${($emojis.Rodando)}  $Mensagem" -ForegroundColor $Cor
}

function Escrever-Info {
    param(
        [string]$Mensagem,
        [ConsoleColor]$Cor = 'Gray'
    )
    Write-Host "${($emojis.Info)}  $Mensagem" -ForegroundColor $Cor
}

function Escrever-Sucesso {
    param(
        [string]$Mensagem
    )
    Write-Host "${($emojis.Sucesso)}  $Mensagem" -ForegroundColor Green
}

function Escrever-Erro {
    param(
        [string]$Mensagem
    )
    Write-Host "${($emojis.Erro)}  $Mensagem" -ForegroundColor Red
}

function Testar-Administrador {
    $identidade = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]$identidade
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Testar-Administrador)) {
    Escrever-Erro "Execute este script em uma janela do PowerShell com privilégios de Administrador para garantir a configuração correta do MiKTeX." 
    exit 1
}

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch {
    Escrever-Info "Não foi possível ajustar o protocolo TLS. Continuando com a configuração padrão." Yellow
}

Escrever-Passo "Verificando se o MiKTeX já está disponível no sistema..."
$miktexExecutavel = Get-Command "mpm.exe" -ErrorAction SilentlyContinue
$miktexJaInstalado = $null -ne $miktexExecutavel

function Obter-CaminhoInstaller {
    param(
        [switch]$Forcar
    )
    $url = "https://miktex.org/download/ctan/systems/win32/miktex/setup/windows-x64/basic-miktex-x64.exe"
    $destino = Join-Path -Path $env:TEMP -ChildPath "basic-miktex-installer.exe"
    if ((-not (Test-Path $destino)) -or $Forcar) {
        Escrever-Passo "Baixando o instalador básico do MiKTeX a partir do espelho oficial..."
        Invoke-WebRequest -Uri $url -OutFile $destino -UseBasicParsing
    } else {
        Escrever-Info "Instalador já encontrado em $destino. Use -ForcarDownload para baixar novamente se necessário."
    }
    return $destino
}

function Instalar-MiktexPorWinget {
    if (Get-Command winget.exe -ErrorAction SilentlyContinue) {
        Escrever-Passo "Instalando MiKTeX via winget em modo silencioso..."
        $argumentos = @("install", "--id", "MiKTeX.MiKTeX", "--silent", "--accept-package-agreements", "--accept-source-agreements")
        $processo = Start-Process -FilePath "winget.exe" -ArgumentList $argumentos -NoNewWindow -Wait -PassThru
        return $processo.ExitCode -eq 0
    }
    return $false
}

if (-not $miktexJaInstalado) {
    Escrever-Passo "MiKTeX não encontrado. Iniciando instalação..."
    $instaladoViaWinget = Instalar-MiktexPorWinget

    if (-not $instaladoViaWinget) {
        Escrever-Info "Winget indisponível ou instalação falhou. Utilizando instalador direto." Yellow
        try {
            $caminhoInstaller = Obter-CaminhoInstaller -Forcar:$ForcarDownload
            Escrever-Passo "Executando instalador básico do MiKTeX em modo silencioso (pacotes compartilhados)..."
            $argumentos = "--unattended --shared --modify-path=yes"
            $processoInstalacao = Start-Process -FilePath $caminhoInstaller -ArgumentList $argumentos -Wait -PassThru
            if ($processoInstalacao.ExitCode -ne 0) {
                throw "Instalador retornou código $($processoInstalacao.ExitCode)"
            }
        } catch {
            Escrever-Erro "Falha ao instalar o MiKTeX: $($_.Exception.Message)"
            exit 1
        }
    }

    $miktexExecutavel = Get-Command "mpm.exe" -ErrorAction SilentlyContinue
    if (-not $miktexExecutavel) {
        Escrever-Erro "MiKTeX não foi localizado após a instalação. Verifique os logs do instalador."
        exit 1
    }
} else {
    Escrever-Info "MiKTeX já está instalado. O script continuará com a configuração de pacotes e repositório." Green
}

$miktexBinarios = Split-Path -Parent $miktexExecutavel.Source
$initexmf = Join-Path -Path $miktexBinarios -ChildPath "initexmf.exe"
$mpm = $miktexExecutavel.Source
$latexmk = Get-Command "latexmk.exe" -ErrorAction SilentlyContinue

if (-not (Test-Path $initexmf)) {
    Escrever-Erro "Não foi possível localizar initexmf.exe. A instalação pode estar corrompida."
    exit 1
}

Escrever-Passo "Definindo o repositório CTAN preferencial para instalações automáticas..."
& $mpm --admin --set-config-value="[MPM]Repository=$RepositorioCTAN" | Out-Null
& $mpm --set-config-value="[MPM]Repository=$RepositorioCTAN" | Out-Null

Escrever-Passo "Habilitando instalação automática de pacotes (on-the-fly) para todos os usuários..."
& $mpm --admin --set-config-value="[MPM]AutoInstall=1" | Out-Null
& $mpm --set-config-value="[MPM]AutoInstall=1" | Out-Null
& $initexmf --admin --set-config-value="[MPM]AutoInstall=1" | Out-Null
& $initexmf --set-config-value="[MPM]AutoInstall=1" | Out-Null

Escrever-Passo "Atualizando a base de dados de pacotes do MiKTeX..."
& $mpm --admin --update-db | Out-Null
& $mpm --admin --update | Out-Null

Escrever-Passo "Garantindo atualização dos formatos e nomes de arquivo..."
& $initexmf --admin --update-fndb | Out-Null
& $initexmf --admin --mklinks --force | Out-Null

Escrever-Passo "Instalando pacotes fundamentais para compilar o TCC sem interrupções..."
$pacotesObrigatorios = @(
    "latexmk",
    "abntex2",
    "abntex2cite",
    "babel-portuges",
    "csquotes",
    "biblatex",
    "biber",
    "xcolor",
    "geometry",
    "hyperref",
    "pgf",
    "xindy",
    "makeindex",
    "lmodern",
    "times",
    "upquote",
    "enumitem",
    "ifmtarg",
    "soul"
)
foreach ($pacote in $pacotesObrigatorios) {
    Escrever-Info "Instalando/atualizando pacote $pacote..."
    & $mpm --admin --install=$pacote | Out-Null
}

if (-not $latexmk) {
    $latexmk = Get-Command "latexmk.exe" -ErrorAction SilentlyContinue
}

if (-not $latexmk) {
    Escrever-Erro "latexmk não encontrado mesmo após a instalação dos pacotes. Verifique a instalação do MiKTeX."
    exit 1
}

Escrever-Sucesso "MiKTeX instalado e configurado com sucesso no modo de instalação automática de pacotes."
Escrever-Info "Agora você pode utilizar o script compila-tcc.ps1 para gerar o PDF do projeto." Cyan
