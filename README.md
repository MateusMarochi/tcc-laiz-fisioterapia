# Template LaTeX para TCC em Fisioterapia

Este repositório reúne um modelo LaTeX configurado para a elaboração de Trabalhos de Conclusão de Curso (TCC) em Fisioterapia da Universidade Tecnológica Federal do Paraná (UTFPR). O template segue as normas da Associação Brasileira de Normas Técnicas (ABNT), com ênfase na NBR 14724/2011, e já inclui recursos específicos para atender aos requisitos institucionais, como listas automáticas, pré-textuais padronizados e exemplos de estruturação dos capítulos.

## Destaques do projeto
- **Conformidade normativa**: Pacotes e estilos ajustados para NBR 14724, NBR 6023, NBR 10520 e demais normas correlatas.
- **Suporte completo a português do Brasil**: Configuração de idioma, hifenização e acentuação UTF-8.
- **Gestão bibliográfica**: Arquivos `.bib` com modelos de referências conforme ABNT e estilos `abntcite`.
- **Recursos gráficos**: Exemplos de inclusão de figuras, tabelas, listas de símbolos e abreviaturas.
- **Scripts auxiliares**: Arquivos batch para compilar rapidamente em ambientes Windows.

## Estrutura recomendada
- `modelo.tex`: documento principal a ser editado com o conteúdo do TCC.
- `*.bib`: bases de referências bibliográficas segmentadas por norma.
- `*.cls`, `*.sty`, `*.def`: classes e estilos que implementam as diretrizes ABNT.
- `*.eps`: figuras de exemplo utilizadas no modelo.

Mantenha todos os arquivos na mesma pasta para garantir a compilação correta do documento.

## Pré-requisitos
- Distribuição LaTeX atualizada (TeX Live, MiKTeX ou similar) com suporte a `latexmk`, `pdflatex`, `bibtex` e pacotes ABNT.
- Compilador capaz de lidar com codificação UTF-8 e fontes Latin Modern.
- Pacotes utilizados no `main.tex`: `abntcite`, `babel`, `breakurl`, `float`, `graphicx`, `hyperref`, `lmodern`, `pifont` e `amsmath` (com `amsfonts` e `amssymb`). Distribuições completas do TeX Live ou MiKTeX instalam todos automaticamente; em instalações mínimas, certifique-se de adicioná-los manualmente.

## Como compilar
1. Ajuste os metadados (autor, título, programa, etc.) no preâmbulo do `modelo.tex`.
2. Atualize os capítulos e seções conforme o roteiro do TCC.
3. Execute a sequência padrão: `pdflatex`, `bibtex`, `pdflatex` e `pdflatex` novamente. Opcionalmente, utilize `latexmk` para automatizar o fluxo.
4. Verifique se listas de figuras, tabelas e abreviaturas estão atualizadas.

Para usuários Windows, os scripts `makeLaTeX.bat` ou `makePDFLaTeX.bat` podem agilizar a compilação. Em sistemas Unix-like, recomenda-se o uso do `latexmk` ou de um Makefile personalizado.

## Personalização
- Atualize os arquivos `.bib` com as referências da pesquisa, mantendo o formato ABNT.
- Substitua as figuras de exemplo (`*.eps`) por gráficos e imagens do trabalho.
- Utilize os comandos já configurados para listas de abreviaturas, símbolos e siglas.
- Revise as configurações de capa, folha de rosto e resumo para refletir os dados oficiais do curso de Fisioterapia.

## Contribuições
Contribuições são bem-vindas! Abra uma issue ou envie um pull request com melhorias, correções ou atualizações das normas. Certifique-se de manter a compatibilidade com as diretrizes ABNT vigentes e com as exigências da UTFPR.
