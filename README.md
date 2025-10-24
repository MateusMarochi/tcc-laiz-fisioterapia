# Template LaTeX para TCC em Fisioterapia

Este repositório reúne um modelo LaTeX configurado para a elaboração de Trabalhos de Conclusão de Curso (TCC) em Fisioterapia da Universidade Tecnológica Federal do Paraná (UTFPR). O template segue as normas da Associação Brasileira de Normas Técnicas (ABNT), com ênfase na NBR 14724/2011, e já inclui recursos específicos para atender aos requisitos institucionais, como listas automáticas, pré-textuais padronizados e exemplos de estruturação dos capítulos.

## Destaques do projeto
- **Conformidade normativa**: Pacotes e estilos ajustados para NBR 14724, NBR 6023, NBR 10520 e demais normas correlatas.
- **Suporte completo a português do Brasil**: Configuração de idioma, hifenização e acentuação UTF-8.
- **Gestão bibliográfica**: Arquivos `.bib` com modelos de referências conforme ABNT e estilos `abntcite`.
- **Recursos gráficos**: Exemplos de inclusão de figuras, tabelas, listas de símbolos e abreviaturas.
- **Scripts auxiliares**: Arquivos batch para compilar rapidamente em ambientes Windows.

## Estrutura recomendada
- `main.tex`, `modelo.tex`, `analise_tcc.tex`: arquivos principais editáveis, mantidos na raiz ao lado dos PDFs de apoio.
- `README.md` e `AGENTS.md`: referências de orientação que permanecem acessíveis na raiz do projeto.
- `tex/estilos/`: classes, estilos e definições personalizados (`*.cls`, `*.sty`, `*.def`, `*.bst`, `*.ist`).
- `tex/bibliografia/`: bases de referências bibliográficas (`*.bib`).
- `assets/licencas/` e `assets/imagens/`: figuras institucionais e exemplos utilizados no template (`*.eps`).
- `scripts/`: utilitários em lote para compilação no Windows.
- `build/`: artefatos gerados automaticamente durante a compilação (logs, arquivos auxiliares, etc.), quando aplicável.
- `docs/`: documentação auxiliar opcional (relatórios de uso, notas de aula ou instruções complementares).

Os arquivos `.tex` já estão configurados para localizar automaticamente os estilos, bibliografias e figuras nas pastas apropriadas, preservando a compilação mesmo com a estrutura organizada.

## Pré-requisitos
- Distribuição LaTeX atualizada (TeX Live, MiKTeX ou similar) com suporte a `latexmk`, `xelatex`, `bibtex` e pacotes ABNT.
- Compilador compatível com `fontspec`, necessário para carregar a fonte Arial (recomenda-se XeLaTeX).
- Pacotes utilizados no `main.tex`: `abntcite`, `babel`, `breakurl`, `float`, `graphicx`, `hyperref`, `lmodern`, `pifont` e `amsmath` (com `amsfonts` e `amssymb`). Distribuições completas do TeX Live ou MiKTeX instalam todos automaticamente; em instalações mínimas, certifique-se de adicioná-los manualmente.

## Como compilar
1. Ajuste os metadados (autor, título, programa, etc.) no preâmbulo do `modelo.tex`.
2. Atualize os capítulos e seções conforme o roteiro do TCC.
3. Compile o projeto com o XeLaTeX para garantir o uso da fonte Arial. Execute `latexmk -xelatex main.tex` ou rode o script `scripts/compilar_tcc.sh` em ambientes Unix-like. No Windows, utilize `scripts\compilar-tcc.ps1` (PowerShell) ou os arquivos `.bat` atualizados para XeLaTeX.
4. Verifique se listas de figuras, tabelas e abreviaturas estão atualizadas.

Para usuários Windows, os scripts `makeLaTeX.bat` ou `makePDFLaTeX.bat` podem agilizar a compilação. Em sistemas Unix-like, recomenda-se o uso do `latexmk` ou de um Makefile personalizado.

## Personalização
- Atualize os arquivos `.bib` com as referências da pesquisa, mantendo o formato ABNT.
- Substitua as figuras de exemplo (`*.eps`) por gráficos e imagens do trabalho.
- Utilize os comandos já configurados para listas de abreviaturas, símbolos e siglas.
- Revise as configurações de capa, folha de rosto e resumo para refletir os dados oficiais do curso de Fisioterapia.

## Contribuições
Contribuições são bem-vindas! Abra uma issue ou envie um pull request com melhorias, correções ou atualizações das normas. Certifique-se de manter a compatibilidade com as diretrizes ABNT vigentes e com as exigências da UTFPR.
