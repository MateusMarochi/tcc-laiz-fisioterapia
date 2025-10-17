# Instruções para agentes

Estas diretrizes se aplicam a todo o repositório e devem ser seguidas com rigor acadêmico.

## Documentos de referência obrigatórios
1. Leia integralmente o `README.md` para compreender o propósito do TCC em Fisioterapia da UTFPR.
2. Estude o arquivo `modelo.tex`, pois ele estabelece a estrutura formal e os padrões de redação que precisam ser preservados.
3. Consulte sempre que necessário as normas ABNT vigentes (NBR 14724, NBR 6023, NBR 10520, NBR 6027 e correlatas), garantindo aderência às regras de formatação, citações e referências.

## Preparação de ambiente
- Ao configurar ou descrever uma máquina virtual, inclua:
  - Distribuição LaTeX completa (preferencialmente TeX Live atual) com suporte aos pacotes ABNT.
  - Ferramentas de compilação `pdflatex`, `bibtex` e `latexmk` configuradas para codificação UTF-8.
  - Scripts auxiliares ou instruções equivalentes aos arquivos `.bat` fornecidos para usuários Windows.
  - Estrutura de diretórios espelhando a raiz deste repositório.

## Organização de diretórios
- Mantenha na raiz apenas `*.tex`, `*.pdf`, `README.md` e este `AGENTS.md`, além dos diretórios principais listados abaixo.
- Insira novos estilos, classes e definições LaTeX em `tex/estilos/`.
- Registre novas referências bibliográficas em `tex/bibliografia/`.
- Armazene figuras e demais mídias em `assets/imagens/` ou `assets/licencas/`, conforme o contexto.
- Adicione scripts auxiliares em `scripts/`, preservando a nomenclatura coerente com os utilitários existentes.
- Utilize `docs/` apenas para materiais complementares que não sejam necessários durante a compilação principal.

## Diretrizes de redação e estilo
- Produza todas as respostas exclusivamente em português do Brasil, adotando linguagem formal compatível com documentos acadêmicos.
- Mantenha concordância e precisão terminológica em conformidade com o vocabulário técnico de fisioterapia presente em `modelo.tex`.
- Ao elaborar trechos textuais, siga a macroestrutura do `modelo.tex`:
  1. Introduções devem contextualizar o tema, explicitar objetivos e apresentar a organização do texto.
  2. Revisões de literatura precisam conter citações diretas ou indiretas conforme NBR 10520, utilizando comandos LaTeX adequados (`\cite`, `\citeonline`, etc.).
  3. Metodologias devem explicitar população, instrumentos, procedimentos e análises estatísticas em parágrafos objetivos.
  4. Resultados e discussões devem relacionar achados com a literatura, empregando tabelas ou figuras numeradas e legendadas conforme NBR 14724.
  5. Conclusões devem retomar objetivos, sintetizar contribuições e sugerir trabalhos futuros.
- Escreva parágrafos coesos com frases completas; evite listas em excesso no corpo textual, exceto quando a norma permitir.
- Garanta que siglas sejam apresentadas por extenso na primeira ocorrência e incluídas na tabela de siglas quando aplicável (`tabela-siglas.ist`).
- Utilize tempos verbais consistentes: pretérito para procedimentos realizados e presente para conceitos consolidados.
- Para citações diretas curtas, mantenha-as entre aspas duplas; para citações longas, empregue o ambiente de citação do `abntex2` com recuo de 4 cm.
- Certifique-se de que todas as referências bibliográficas estejam cadastradas em `normas.bib` ou arquivos correlatos, obedecendo à NBR 6023.

## Formatação técnica
- Ao fornecer exemplos de código ou comandos, utilize LaTeX ou shell script conforme apropriado, mantendo a sintaxe demonstrada em `modelo.tex`.
- Evite outros formatos de marcação, a menos que o `README.md` solicite explicitamente.
- Mantenha o alinhamento de equações e tabelas conforme padrões ABNT, utilizando ambientes `equation`, `table` e `figure` com legendas centralizadas.

## Interação com usuários
- Inclua pelo menos um emoji relevante em cada resposta final para sinalizar status ou contexto.
- Destaque passos importantes com listas numeradas ou marcadores quando adequado.

## Registro de conformidade ABNT
- Informe, ao final de cada execução, como as diretrizes ABNT foram consideradas durante a preparação da máquina virtual ou das instruções fornecidas.
