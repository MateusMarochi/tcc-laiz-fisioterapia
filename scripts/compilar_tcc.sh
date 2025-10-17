#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
TEX_PRINCIPAL="${REPO_ROOT}/main.tex"
SAIDA_DIR="${REPO_ROOT}/build"
BIN_LOCAL="${REPO_ROOT}/scripts/bin"

mkdir -p "${BIN_LOCAL}"
export PATH="${BIN_LOCAL}:${PATH}"

if [ ! -f "${TEX_PRINCIPAL}" ]; then
  echo "Arquivo principal main.tex não encontrado na raiz do repositório." >&2
  exit 1
fi

checar_comando() {
  local comando="$1"
  if command -v "${comando}" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

solicitar_instalacao() {
  local pacote="$1"
  pacotes_faltantes+=("${pacote}")
}

instalar_pacotes() {
  local pacotes=("$@")
  if [ ${#pacotes[@]} -eq 0 ]; then
    return 0
  fi

  if ! command -v apt-get >/dev/null 2>&1; then
    echo "apt-get não está disponível. Instale manualmente os pacotes: ${pacotes[*]}" >&2
    exit 1
  fi

  local prefixo_sudo=""
  if [ "${EUID}" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
      prefixo_sudo="sudo"
    else
      echo "Permissões elevadas são necessárias para instalar pacotes: ${pacotes[*]}" >&2
      exit 1
    fi
  fi

  ${prefixo_sudo} apt-get update
  ${prefixo_sudo} apt-get install -y "${pacotes[@]}"
}

pacotes_faltantes=()

if ! checar_comando latexmk; then
  solicitar_instalacao latexmk
fi

if ! checar_comando pdflatex; then
  solicitar_instalacao texlive-latex-extra
fi

if ! checar_comando bibtex; then
  solicitar_instalacao texlive-bibtex-extra
fi

if ! checar_comando makeglossaries; then
  solicitar_instalacao texlive-lang-portuguese
fi

if ! checar_comando repstopdf; then
  solicitar_instalacao texlive-extra-utils
fi

if ! checar_comando repstopdf; then
  echo "repstopdf não encontrado após instalação. Verifique se o script em scripts/bin/repstopdf está presente." >&2
  exit 1
fi

if ! checar_comando gs; then
  solicitar_instalacao ghostscript
fi

if [ ${#pacotes_faltantes[@]} -gt 0 ]; then
  instalar_pacotes "${pacotes_faltantes[@]}"
fi

rm -rf "${SAIDA_DIR}"
mkdir -p "${SAIDA_DIR}"

latexmk -pdf -interaction=nonstopmode -synctex=1 -output-directory="${SAIDA_DIR}" "${TEX_PRINCIPAL}"

cp "${SAIDA_DIR}/main.pdf" "${SAIDA_DIR}/tcc_compilado.pdf"

find "${REPO_ROOT}/assets/licencas" -maxdepth 1 -type f -name '*-eps-converted-to.pdf' -delete

echo "Compilação concluída. O PDF está disponível em ${SAIDA_DIR}/tcc_compilado.pdf"
