<#
    Script para compilar os arquivos .tex do TCC utilizando o MiKTeX.
    Executa latexmk (ou sequência manual) garantindo conformidade com as normas ABNT.
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$ArquivoPrincipal = "../main.tex",

    [switch]$Limpar,

    [switch]$SomenteBib,

    [switch]$SemGlossario
)

function Escrever-Passo {
    param([string]$Mensagem)
    Write-Host "\n📄  $Mensagem" -ForegroundColor Cyan
}

function Escrever-Sucesso {
    param([string]$Mensagem)
    Write-Host "🏁  $Mensagem" -ForegroundColor Green
}

function Escrever-Aviso {
    param([string]$Mensagem)
    Write-Host "⚠️  $Mensagem" -ForegroundColor Yellow
}

function Escrever-Erro {
    param([string]$Mensagem)
    Write-Host "❌  $Mensagem" -ForegroundColor Red
}

function Normalizar-ArquivoPrincipal {
    $arquivo = $ArquivoPrincipal

    if ([string]::IsNullOrWhiteSpace($arquivo)) {
        $arquivo = "../main.tex"
    }

    if (-not [System.IO.Path]::HasExtension($arquivo)) {
        $arquivo = "$arquivo.tex"
    }

    $caminhoResolvido = Resolve-Path -Path $arquivo -ErrorAction SilentlyContinue
    if ($caminhoResolvido) {
        $arquivoCompleto = $caminhoResolvido.ProviderPath
    } else {
        $arquivoCompleto = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $arquivo))
    }

    $script:ArquivoPrincipal = $arquivoCompleto
    Set-Variable -Name ArquivoPrincipal -Scope Script -Value $arquivoCompleto
    $script:DiretorioFonte = Split-Path -Path $arquivoCompleto -Parent
    if (-not $script:DiretorioFonte) {
        $script:DiretorioFonte = Get-Location
    }
    $script:ArquivoPrincipalNome = [System.IO.Path]::GetFileName($arquivoCompleto)
    $script:ArquivoPrincipalBase = [System.IO.Path]::GetFileNameWithoutExtension($arquivoCompleto)
}

function Testar-ArquivoPrincipal {
    if (-not (Test-Path $script:ArquivoPrincipal)) {
        Escrever-Erro "Arquivo $script:ArquivoPrincipal não encontrado. Execute o script na pasta do projeto ou informe o caminho completo."
        exit 1
    }
}

function Definir-DiretorioProjeto {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
    if ($scriptDir -and (Test-Path $scriptDir)) {
        Set-Location $scriptDir
        Set-Location ..
    }
}

function Garantir-Executaveis {
    $latexmk = Get-Command "latexmk" -ErrorAction SilentlyContinue
    $xelatex = Get-Command "xelatex" -ErrorAction SilentlyContinue
    if (-not $latexmk) {
        Escrever-Aviso "latexmk não encontrado. A compilação utilizará a sequência xelatex/bibtex."
    }
    if (-not $xelatex) {
        Escrever-Erro "xelatex não encontrado. Verifique se o MiKTeX (ou TeX Live) está instalado e no PATH."
        exit 1
    }
}

function Executar-Latexmk {
    param(
        [switch]$Limpar,
        [switch]$SomenteBib,
        [switch]$SemGlossario
    )
    $argumentos = @("-xelatex", "-interaction=nonstopmode", "-synctex=1", $script:ArquivoPrincipalNome)
    if ($Limpar) { $argumentos += "-C" }
    if ($SomenteBib) { $argumentos += "-bibtex" }
    if ($SemGlossario) { $argumentos += "-e", "\$makeindex='makeindex -s tabela-siglas.ist';", "-e", "\$makeglossaries='';" }

    Escrever-Passo "Executando latexmk com argumentos: $($argumentos -join ' ')"
    $processo = Start-Process -FilePath "latexmk" -ArgumentList $argumentos -WorkingDirectory $script:DiretorioFonte -Wait -PassThru -NoNewWindow
    return $processo.ExitCode
}

function Sequencia-Manual {
    Escrever-Passo "Iniciando sequência manual xelatex → bibtex → xelatex ×2"
    $comandos = @(
        @{ Nome = "xelatex"; Args = @("-interaction=nonstopmode", $script:ArquivoPrincipalNome) },
        @{ Nome = "bibtex"; Args = @($script:ArquivoPrincipalBase) },
        @{ Nome = "xelatex"; Args = @("-interaction=nonstopmode", $script:ArquivoPrincipalNome) },
        @{ Nome = "xelatex"; Args = @("-interaction=nonstopmode", $script:ArquivoPrincipalNome) }
    )

    foreach ($cmd in $comandos) {
        Escrever-Passo "Executando $($cmd.Nome) ..."
        $processo = Start-Process -FilePath $cmd.Nome -ArgumentList $cmd.Args -WorkingDirectory $script:DiretorioFonte -Wait -PassThru -NoNewWindow
        if ($processo.ExitCode -ne 0) {
            Escrever-Erro "$($cmd.Nome) retornou código $($processo.ExitCode). Verifique o arquivo .log para detalhes."
            exit $processo.ExitCode
        }
    }

    Escrever-Sucesso "Compilação concluída com sucesso pela sequência manual."
}

try {
    Definir-DiretorioProjeto
    Normalizar-ArquivoPrincipal
    Escrever-Passo "Compilando arquivo principal: $script:ArquivoPrincipal"
    Testar-ArquivoPrincipal
    Garantir-Executaveis

    Push-Location -Path $script:DiretorioFonte
    try {
        $latexmk = Get-Command "latexmk" -ErrorAction SilentlyContinue
        if ($latexmk) {
            $codigo = Executar-Latexmk -Limpar:$Limpar -SomenteBib:$SomenteBib -SemGlossario:$SemGlossario
            if ($codigo -ne 0) {
                Escrever-Aviso "latexmk retornou código $codigo. Tentando sequência manual como fallback."
                Sequencia-Manual
            } else {
                Escrever-Sucesso "PDF gerado com latexmk sem erros."
            }
        } else {
            Sequencia-Manual
        }

        if (-not $SemGlossario) {
            $arquivoIndice = @("tabela-siglas.ist", "tex/estilos/tabela-siglas.ist") | Where-Object { Test-Path $_ } | Select-Object -First 1
            if ($arquivoIndice) {
                Escrever-Passo "Atualizando índices de siglas e símbolos conforme ABNT..."
                if (Test-Path "$script:ArquivoPrincipalBase.glo") {
                    makeindex -s $arquivoIndice -t "$script:ArquivoPrincipalBase.glg" -o "$script:ArquivoPrincipalBase.gls" "$script:ArquivoPrincipalBase.glo"
                }
                if (Test-Path "$script:ArquivoPrincipalBase.acr") {
                    makeindex -s $arquivoIndice -t "$script:ArquivoPrincipalBase.alg" -o "$script:ArquivoPrincipalBase.acr" "$script:ArquivoPrincipalBase.acn"
                }
            }
        }

        if ($Limpar) {
            Escrever-Passo "Removendo arquivos temporários..."
            $extensoes = @("aux","bbl","blg","fls","fdb_latexmk","log","out","synctex.gz","toc","lot","lof","ist","ilg","glg","glo","gls","acr","acn","alg")
            foreach ($ext in $extensoes) {
                Get-ChildItem -Filter "*.$ext" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
            }
        }
    }
    finally {
        Pop-Location
    }

    Escrever-Sucesso "Processo finalizado. Verifique o PDF gerado na pasta do projeto."
} catch {
    Escrever-Erro "Falha durante a compilação: $($_.Exception.Message)"
    throw
}
