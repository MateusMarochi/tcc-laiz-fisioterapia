<#
    Script para compilar os arquivos .tex do TCC utilizando o MiKTeX.
    Executa latexmk (ou sequência manual) garantindo conformidade com as normas ABNT.
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$ArquivoPrincipal = "modelo.tex",

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

function Testar-ArquivoPrincipal {
    if (-not (Test-Path $ArquivoPrincipal)) {
        Escrever-Erro "Arquivo $ArquivoPrincipal não encontrado. Execute o script na pasta do projeto ou informe o caminho completo."
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
    $pdflatex = Get-Command "pdflatex" -ErrorAction SilentlyContinue
    if (-not $latexmk) {
        Escrever-Aviso "latexmk não encontrado. A compilação utilizará a sequência pdflatex/bibtex."
    }
    if (-not $pdflatex) {
        Escrever-Erro "pdflatex não encontrado. Verifique se o MiKTeX está instalado e no PATH."
        exit 1
    }
}

function Executar-Latexmk {
    param(
        [switch]$Limpar,
        [switch]$SomenteBib,
        [switch]$SemGlossario
    )
    $argumentos = @("-pdf", "-interaction=nonstopmode", "-synctex=1", $ArquivoPrincipal)
    if ($Limpar) { $argumentos += "-C" }
    if ($SomenteBib) { $argumentos += "-bibtex" }
    if ($SemGlossario) { $argumentos += "-e", "\$makeindex='makeindex -s tabela-siglas.ist';", "-e", "\$makeglossaries='';" }

    Escrever-Passo "Executando latexmk com argumentos: $($argumentos -join ' ')"
    $processo = Start-Process -FilePath "latexmk" -ArgumentList $argumentos -Wait -PassThru -NoNewWindow
    return $processo.ExitCode
}

function Sequencia-Manual {
    Escrever-Passo "Iniciando sequência manual pdflatex → bibtex → pdflatex ×2"
    $comandos = @(
        @{ Nome = "pdflatex"; Args = @("-interaction=nonstopmode", $ArquivoPrincipal) },
        @{ Nome = "bibtex"; Args = @([System.IO.Path]::GetFileNameWithoutExtension($ArquivoPrincipal)) },
        @{ Nome = "pdflatex"; Args = @("-interaction=nonstopmode", $ArquivoPrincipal) },
        @{ Nome = "pdflatex"; Args = @("-interaction=nonstopmode", $ArquivoPrincipal) }
    )

    foreach ($cmd in $comandos) {
        Escrever-Passo "Executando $($cmd.Nome) ..."
        $processo = Start-Process -FilePath $cmd.Nome -ArgumentList $cmd.Args -Wait -PassThru -NoNewWindow
        if ($processo.ExitCode -ne 0) {
            Escrever-Erro "$($cmd.Nome) retornou código $($processo.ExitCode). Verifique o arquivo .log para detalhes."
            exit $processo.ExitCode
        }
    }

    Escrever-Sucesso "Compilação concluída com sucesso pela sequência manual."
}

try {
    Definir-DiretorioProjeto
    Testar-ArquivoPrincipal
    Garantir-Executaveis

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

    if (-not $SemGlossario -and (Test-Path "tabela-siglas.ist")) {
        Escrever-Passo "Atualizando índices de siglas e símbolos conforme ABNT..."
        $nomeBase = [System.IO.Path]::GetFileNameWithoutExtension($ArquivoPrincipal)
        if (Test-Path "$nomeBase.glo") {
            makeindex -s tabela-siglas.ist -t "$nomeBase.glg" -o "$nomeBase.gls" "$nomeBase.glo"
        }
        if (Test-Path "$nomeBase.acr") {
            makeindex -s tabela-siglas.ist -t "$nomeBase.alg" -o "$nomeBase.acr" "$nomeBase.acn"
        }
    }

    if ($Limpar) {
        Escrever-Passo "Removendo arquivos temporários..."
        $extensoes = @("aux","bbl","blg","fls","fdb_latexmk","log","out","synctex.gz","toc","lot","lof","ist","ilg","glg","glo","gls","acr","acn","alg")
        foreach ($ext in $extensoes) {
            Get-ChildItem -Filter "*.$ext" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        }
    }

    Escrever-Sucesso "Processo finalizado. Verifique o PDF gerado na pasta do projeto."
} catch {
    Escrever-Erro "Falha durante a compilação: $($_.Exception.Message)"
    throw
}
