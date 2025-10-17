<#
    Script: compila-tcc.ps1
    Objetivo: compilar o projeto LaTeX principal deste repositório no Windows,
              utilizando o MiKTeX com instalação automática de pacotes.
#>
[CmdletBinding()]
param(
    [string]$ArquivoPrincipal = "main.tex",
    [switch]$LimparCache
)

$emojis = [PSCustomObject]@{
    Info    = "ℹ️"
    Sucesso = "✅"
    Erro    = "❌"
    Passo   = "🛠️"
}

function Escrever {
    param(
        [string]$Mensagem,
        [ConsoleColor]$Cor = 'Cyan',
        [string]$Emoji = $emojis.Passo
    )
    Write-Host "$Emoji  $Mensagem" -ForegroundColor $Cor
}

function Validar-Arquivo {
    param(
        [string]$Caminho
    )
    if (-not (Test-Path $Caminho)) {
        Escrever "Arquivo $Caminho não foi encontrado. Certifique-se de executar o script na raiz do repositório." Red $emojis.Erro
        exit 1
    }
}

Escrever "Verificando ferramentas essenciais do MiKTeX..."
$latexmk = Get-Command "latexmk.exe" -ErrorAction SilentlyContinue
if (-not $latexmk) {
    Escrever "latexmk não encontrado no PATH. Execute setup-miktex.ps1 antes de compilar." Red $emojis.Erro
    exit 1
}

Escrever "Confirmando presença do arquivo LaTeX principal $ArquivoPrincipal..."
Validar-Arquivo -Caminho $ArquivoPrincipal

$diretorioSaida = Split-Path -Path $ArquivoPrincipal -Parent
if ([string]::IsNullOrWhiteSpace($diretorioSaida)) {
    $diretorioSaida = Get-Location
}

if ($LimparCache) {
    Escrever "Limpando arquivos auxiliares anteriores..." Yellow $emojis.Info
    & $latexmk.Source -c $ArquivoPrincipal | Out-Null
    Get-ChildItem -Path $diretorioSaida -Include "*.aux","*.bbl","*.bcf","*.blg","*.glg","*.glo","*.gls","*.ist","*.log","*.lot","*.lof","*.out","*.run.xml","*.toc","*.synctex*" -Recurse -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
}

Escrever "Iniciando compilação completa com latexmk (pdflatex + bibtex/biber automáticos)..."
$argumentosLatexmk = @("-pdf", "-synctex=1", "-interaction=nonstopmode", "-file-line-error", $ArquivoPrincipal)
$processo = Start-Process -FilePath $latexmk.Source -ArgumentList $argumentosLatexmk -Wait -NoNewWindow -PassThru

if ($processo.ExitCode -ne 0) {
    Escrever "A compilação retornou código $($processo.ExitCode). Verifique os logs gerados para identificar o problema." Red $emojis.Erro
    exit $processo.ExitCode
}

$pdfGerado = [System.IO.Path]::ChangeExtension((Resolve-Path $ArquivoPrincipal), ".pdf")
if (Test-Path $pdfGerado) {
    Escrever "PDF gerado com sucesso em $pdfGerado" Green $emojis.Sucesso
} else {
    Escrever "Compilação finalizada, mas o PDF não foi localizado. Revise os arquivos auxiliares." Yellow $emojis.Info
}

Escrever "Compilação concluída. Utilize um leitor de PDF compatível para revisar a formatação segundo as normas ABNT." Green $emojis.Sucesso
