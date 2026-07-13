# TP2 — Auditoria Visual do Jogo "Detetive x Ladrão" (Haskell)

Trabalho Prático de CSI107 (Linguagens de Programação, DECSI/UFOP).

Ferramenta em Haskell que faz o *parsing* do log de uma partida do jogo
"Detetive x Ladrão" (TP1) e gera um grafo no formato **DOT** (Graphviz),
mostrando:

- **vermelho** — arestas percorridas pelo ladrão;
- **azul** — arestas percorridas pelo detetive (se ambos passaram pela
  mesma aresta, são geradas arestas paralelas, uma de cada cor);
- **nó dourado em `doublecircle`** — cidades onde ocorreram eventos de
  roubo, com o item roubado no rótulo do nó;
- o rótulo de cada aresta lista os turnos em que ela foi percorrida
  (ex.: `T16, T20`).

## Estrutura do projeto

```
src/
  Main.hs        -- ponto de entrada: todo o I/O fica isolado aqui
  Parser.hs      -- parsing puro do log -> [Registro]
  GeradorDot.hs  -- geração pura da String do arquivo .dot
  Tipos.hs       -- tipos de dados (Agente, Acao, Registro)
testes/
  exemplo_enunciado.log  -- log fornecido no enunciado
  partida2.log           -- partida com detetive em movimento e 2 roubos
saidas/
  exemplo_enunciado.dot  -- saída gerada para o primeiro log
  partida2.dot           -- saída gerada para o segundo log
```

## Como compilar

Com **GHC** (>= 9.x, apenas bibliotecas padrão — nenhuma dependência externa):

```bash
ghc -O2 -isrc src/Main.hs -o log2dot
```

Ou com **Stack** (baixa o GHC automaticamente na primeira vez):

```bash
stack --resolver ghc-9.8.4 ghc -- -O2 -isrc src/Main.hs -o log2dot
```

## Como executar

```bash
# lê o log e grava o .dot
./log2dot testes/exemplo_enunciado.log saidas/exemplo_enunciado.dot

# ou imprime o .dot na saída padrão
./log2dot testes/exemplo_enunciado.log

# ou como filtro (stdin -> stdout)
./log2dot < testes/partida2.log > saidas/partida2.dot
```

Para visualizar o grafo com o Graphviz:

```bash
dot -Tjpeg saidas/exemplo_enunciado.dot -o exemplo_enunciado.jpeg
```

(ou cole o conteúdo do `.dot` em uma ferramenta online como o
[GraphvizOnline](https://dreampuf.github.io/GraphvizOnline/)).

## Arquitetura funcional

O programa segue a arquitetura clássica de *pipeline* funcional, com o
núcleo 100% puro e o efeito colateral confinado ao `main`:

```
String (log)  --parseLog-->  [Registro]  --gerarDot-->  String (.dot)
└──────────── converter = gerarDot . parseLog ────────────┘
```

- **Imutabilidade**: não há variáveis globais nem estruturas mutáveis.
  Todo o estado da conversão flui por parâmetros; os agrupamentos de
  arestas/roubos e a separação de argumentos usam recursão com
  acumuladores (`separarArgs` carrega a profundidade de parênteses como
  parâmetro; `semRepeticao` acumula os elementos já vistos).
- **Funções puras**: `Parser` e `GeradorDot` são inteiramente puros —
  recebem `String`/listas e devolvem novos valores. A leitura do log e a
  escrita do `.dot` acontecem apenas na função monádica `main`
  (`Main.hs`), como exige o enunciado.
- **Funções de alta ordem e recursão explícita**: além de `map`,
  `unlines`, compreensões de lista com guardas e composição de funções
  (`.`), as funções auxiliares centrais foram escritas por recursão
  explícita em vez de importadas prontas: `filtrarJust` (equivalente a
  `mapMaybe`), `semRepeticao` (equivalente a `nub`), `quickSortPor`
  (ordenação por comparador) e `juntarCom` (equivalente a
  `intercalate`).
- **Casamento de padrões**: cada comando do log é interpretado por
  padrões — `termoParaAcao "move" [o,d] = Move o d`,
  `termoParaAcao "roubar" [i] = Roubar i`, etc. As compreensões de lista
  em `GeradorDot` também filtram por padrão
  (`RegistroAcao t ag (Move o d) True <- regs`), de modo que só os
  movimentos bem-sucedidos (`[OK]`) viram arestas.

### Decisões de projeto

- Linhas que não são ações nem eventos (estado final `S = gSt(...)`,
  `V = ...`, linhas em branco) são descartadas pelo parser
  (`parseLinha` devolve `Nothing`), tornando a ferramenta robusta a
  variações do log.
- Ações com status diferente de `[OK]` (ex.: um `move` que falhou) são
  registradas, mas **não** geram arestas — o agente não atravessou o
  caminho.
- Ações que não afetam o grafo (`nada`, `fechar`, `pedir_mandato`,
  `inspecionar`) são reconhecidas e ignoradas na geração do grafo;
  functores desconhecidos caem no construtor genérico `Outra`, o que
  torna o parser tolerante a extensões do jogo.
- A cidade de um roubo vem do evento global
  (`>>>> Evento roubo(Item, Cidade, Pistas)`), que é quem carrega a
  localização; a ação `roubar(Item)` do ladrão não menciona a cidade.

## Autores

- Jasmin Andrade Cordeiro — 22.2.8104
- Pedro Henrique Amaral Estevão — 22.1.8079
