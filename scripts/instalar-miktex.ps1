<#
    Script de preparação do ambiente LaTeX para Windows.
    Instala o MiKTeX com modo on-the-fly habilitado e adiciona dependências
    necessárias para compilar o TCC conforme as normas ABNT vigentes.
#>

[CmdletBinding()]
param(
    [switch]$ForcarRepositorioBasico,
    [switch]$AtualizarSomente
)

function Escrever-Passo {
    param([string]$Mensagem)
    Write-Host "\n🛠️  $Mensagem" -ForegroundColor Cyan
}

function Escrever-Sucesso {
    param([string]$Mensagem)
    Write-Host "✅  $Mensagem" -ForegroundColor Green
}

function Escrever-Aviso {
    param([string]$Mensagem)
    Write-Host "⚠️  $Mensagem" -ForegroundColor Yellow
}

function Escrever-Erro {
    param([string]$Mensagem)
    Write-Host "❌  $Mensagem" -ForegroundColor Red
}

function Testar-Administrador {
    $identidade = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identidade)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Escrever-Erro "Execute o PowerShell como Administrador para continuar."
        exit 1
    }
}

function Configurar-TLS {
    Escrever-Passo "Habilitando protocolos TLS atuais para downloads confiáveis..."
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

function Garantir-DiretorioTemp {
    if (-not (Test-Path -Path $env:TEMP)) {
        Escrever-Passo "Criando diretório temporário em $($env:TEMP) ..."
        New-Item -ItemType Directory -Path $env:TEMP -Force | Out-Null
    }
}

function Obter-Comando {
    param(
        [string]$Nome
    )
    return Get-Command $Nome -ErrorAction SilentlyContinue
}

function Baixar-Arquivo {
    param(
        [string]$Url,
        [string]$Destino
    )
    Escrever-Passo "Baixando $Url ..."
    Invoke-WebRequest -Uri $Url -OutFile $Destino -UseBasicParsing
}

function Instalar-MiKTeX {
    $mpm = Obter-Comando "mpm"
    $miktexConsole = Join-Path $env:ProgramFiles "MiKTeX\\miktex\\bin\\x64\\mpm.exe"
    if (-not $mpm -and (Test-Path $miktexConsole)) {
        $mpm = Get-Item $miktexConsole
    }

    if ($AtualizarSomente) {
        if (-not $mpm) {
            Escrever-Erro "MiKTeX não encontrado. Execute o script sem -AtualizarSomente para instalar."
            exit 1
        }
        Escrever-Passo "Atualizando banco de pacotes do MiKTeX..."
        & $mpm --admin --update-db
        & $mpm --admin --update
        return
    }

    if ($mpm) {
        Escrever-Aviso "MiKTeX já identificado no sistema. Prosseguindo com a atualização das configurações."
    } else {
        $arquivoInstalador = Join-Path $env:TEMP "basic-miktex-x64.exe"
        $urlPadrao = "https://mirrors.ctan.org/systems/win32/miktex/setup/windows-x64/basic-miktex-x64.exe"
        $urlFallback = "https://miktex.org/download/win/miktexsetup-x64.exe"

        try {
            Baixar-Arquivo -Url $urlPadrao -Destino $arquivoInstalador
        } catch {
            Escrever-Aviso "Mirror principal indisponível. Tentando URL alternativa..."
            Baixar-Arquivo -Url $urlFallback -Destino $arquivoInstalador
        }

        $argumentos = @("--unattended", "--package-set=complete", "--shared")
        if (-not $ForcarRepositorioBasico) {
            $argumentos += "--auto-install=yes"
        }

        Escrever-Passo "Instalando MiKTeX em modo silencioso..."
        $instalacao = Start-Process -FilePath $arquivoInstalador -ArgumentList $argumentos -Wait -PassThru -NoNewWindow
        if ($instalacao.ExitCode -ne 0) {
            Escrever-Erro "A instalação do MiKTeX retornou o código $($instalacao.ExitCode)."
            exit $instalacao.ExitCode
        }
        Escrever-Sucesso "MiKTeX instalado com sucesso."
        $mpm = Obter-Comando "mpm"
    }

    if (-not $mpm) {
        Escrever-Erro "Não foi possível localizar o gerenciador de pacotes do MiKTeX após a instalação."
        exit 1
    }

    Escrever-Passo "Habilitando instalação de pacotes on-the-fly (AutoInstall=1)..."
    & "initexmf" --admin --set-config-value=[MPM]AutoInstall=1
    & "initexmf" --admin --set-config-value=[MPM]AutoLoad=1

    Escrever-Passo "Atualizando estruturas de arquivos do MiKTeX..."
    & "initexmf" --admin --update-fndb
    & "initexmf" --admin --mklinks --force

    Escrever-Passo "Instalando pacotes essenciais para o template ABNT..."
    $pacotes = @(
        "abntex2",
        "babel-portuges",
        "csquotes",
        "enumitem",
        "float",
        "geometry",
        "graphics",
        "hyperref",
        "ifluatex",
        "latexmk",
        "lipsum",
        "lmodern",
        "microtype",
        "pifont",
        "textcomp",
        "xcolor",
        "biblatex",
        "biber",
        "pdfpages",
        "setspace",
        "glossaries-extra"
    )

    foreach ($pacote in $pacotes) {
        Escrever-Passo "Verificando pacote: $pacote"
        & $mpm --admin --find-package=$pacote --verbose | Out-Null
        & $mpm --admin --install=$pacote --verbose
    }

    Escrever-Sucesso "Pacotes principais garantidos."
}

function Instalar-DependenciasComplementares {
    Escrever-Passo "Verificando presença do Ghostscript (necessário para arquivos EPS)..."
    if (-not (Obter-Comando "gswin64c")) {
        if (Obter-Comando "winget") {
            Escrever-Passo "Instalando Ghostscript via winget..."
            winget install --id ArtifexSoftware.GhostScript --source winget --accept-package-agreements --accept-source-agreements
        } elseif (Obter-Comando "choco") {
            Escrever-Passo "Instalando Ghostscript via Chocolatey..."
            choco install ghostscript -y
        } else {
            Escrever-Aviso "Instale o Ghostscript manualmente (https://ghostscript.com/releases/gsdnld.html) para suporte a EPS."
        }
    } else {
        Escrever-Sucesso "Ghostscript já disponível."
    }

    Escrever-Passo "Garantindo o Perl necessário para o latexmk..."
    if (-not (Obter-Comando "perl")) {
        if (Obter-Comando "winget") {
            Escrever-Passo "Instalando Strawberry Perl via winget..."
            winget install --id StrawberryPerl.StrawberryPerl --source winget --accept-package-agreements --accept-source-agreements
        } elseif (Obter-Comando "choco") {
            Escrever-Passo "Instalando Strawberry Perl via Chocolatey..."
            choco install strawberryperl -y
        } else {
            Escrever-Aviso "Perl não encontrado. Instale o Strawberry Perl manualmente (https://strawberryperl.com/) para usar o latexmk."
        }
    } else {
        Escrever-Sucesso "Perl disponível."
    }
}

try {
    Testar-Administrador
    Configurar-TLS
    Garantir-DiretorioTemp
    Instalar-MiKTeX
    Instalar-DependenciasComplementares
    Escrever-Sucesso "Ambiente configurado! Reinicie o PowerShell para carregar os novos caminhos, se necessário."
} catch {
    Escrever-Erro "Ocorreu um erro inesperado: $($_.Exception.Message)"
    throw
}
