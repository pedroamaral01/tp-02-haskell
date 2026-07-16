# TP2 - Auditoria Visual do Jogo "Detetive x Ladrão" (Haskell)

Trabalho Prático 2 de CSI107 (Linguagens de Programação, DECSI/UFOP).

**Autores:**
- Jasmin Andrade Cordeiro - 22.2.8104
- Pedro Henrique Amaral Estevão - 22.1.8079

Programa em Haskell que lê o log de uma partida do jogo "Detetive x
Ladrão" (TP1) e gera um grafo no formato DOT (Graphviz), mostrando:

- **vermelho**: arestas por onde o ladrão passou;
- **azul**: arestas por onde o detetive passou (se os dois passaram pela
  mesma aresta, saem duas arestas paralelas, uma de cada cor);
- **nó dourado em `doublecircle`**: cidades onde ocorreu roubo, com o
  item roubado no rótulo do nó;
- o rótulo de cada aresta lista os turnos em que ela foi percorrida
  (ex.: `T16, T20`).

## Estrutura do projeto

```
src/
  Main.hs        -- ponto de entrada, todo o I/O fica aqui
  Parser.hs      -- parsing do log -> [Registro]
  GeradorDot.hs  -- geração da String do arquivo .dot
  Tipos.hs       -- tipos de dados (Agente, Acao, Registro)
testes/
  exemplo_enunciado.log  -- log fornecido no enunciado
  partida2.log           -- partida com detetive em movimento e 2 roubos
  partida3.log           -- partida longa com 4 roubos e status colado na ação
saidas/
  exemplo_enunciado.dot  -- saída gerada para o primeiro log (+ .png)
  partida2.dot           -- saída gerada para o segundo log (+ .png)
  partida3.dot           -- saída gerada para o terceiro log (+ .png)
```

## Como compilar

Com GHC (só bibliotecas padrão, nenhuma dependência externa):

```bash
ghc -O2 -isrc src/Main.hs -o log2dot
```

Ou com Stack (baixa o GHC automaticamente na primeira vez):

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

Também dá para colar o conteúdo do `.dot` em uma ferramenta online como
o GraphvizOnline (https://dreampuf.github.io/GraphvizOnline/).

## Arquitetura funcional

O programa é um pipeline de funções puras, com o efeito colateral
restrito ao `main`:

```
String (log)  --parseLog-->  [Registro]  --gerarDot-->  String (.dot)
```

A conversão completa é a composição `converter = gerarDot . parseLog`.

Como o enunciado pede:

- **Imutabilidade**: não há variáveis globais nem estruturas mutáveis.
  O estado da conversão flui por parâmetros; onde é preciso "lembrar"
  algo usamos recursão com acumulador (`separarArgs` carrega a
  profundidade de parênteses, `semRepeticao` acumula os elementos já
  vistos).
- **Funções puras**: `Parser` e `GeradorDot` só recebem valores e
  devolvem valores novos. A leitura do log e a escrita do `.dot`
  acontecem apenas na função monádica `main` (`Main.hs`).
- **Funções de alta ordem**: usamos `map`, `unlines`, composição (`.`)
  e compreensões de lista com guardas. Algumas auxiliares foram
  escritas com recursão explícita em vez de importadas prontas:
  `filtrarJust` (faz o papel do `mapMaybe`), `semRepeticao` (`nub`),
  `quickSortPor` (ordenação por comparador) e `juntarCom`
  (`intercalate`).
- **Casamento de padrões**: cada comando do log é interpretado por
  padrões (`termoParaAcao "move" [o,d] = Move o d`,
  `termoParaAcao "roubar" [i] = Roubar i`, etc.). As compreensões de
  lista do `GeradorDot` também filtram por padrão
  (`RegistroAcao t ag (Move o d) True <- regs`), então só os movimentos
  com `[OK]` viram arestas.

## Decisões de projeto

- Linhas que não são ações nem eventos (estado final `S = gSt(...)`,
  `V = ...`, linhas em branco) são descartadas pelo parser.
- Ações com status diferente de `[OK]` (ex.: um `move` que falhou) são
  registradas mas não geram arestas, já que o agente não atravessou o
  caminho.
- O marcador de status pode vir separado por espaço (`move(c,d) [OK]`)
  ou colado na ação (`move(c,d)[OK]`); os dois formatos aparecem nos
  logs do jogo e os dois são aceitos.
- Ações que não afetam o grafo (`nada`, `fechar`, `pedir_mandato`,
  `inspecionar`, `disfarce`) são reconhecidas e ignoradas na geração;
  ações desconhecidas caem no construtor genérico `Outra`.
- A cidade de um roubo vem do evento global
  (`>>>> Evento roubo(Item, Cidade, Pistas)`), que é quem carrega a
  localização; a ação `roubar(Item)` do ladrão não menciona a cidade.
