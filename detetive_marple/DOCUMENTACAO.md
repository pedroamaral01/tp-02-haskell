# Detetive Marple

Trabalho Prático de CSI107 (Linguagens de Programação, DECSI/UFOP)

Autores:

- Jasmin Andrade Cordeiro, matrícula 22.2.8104
- Pedro Henrique Amaral Estevão, matrícula 22.1.8079

## Arquivo entregue

`detetive_marple.prolog`: agente detetive para o Jogo do Detetive e Ladrão.

## Como usar

O agente é carregado pelo motor `Interactor.prolog` via `gameStart/6`. Para rodar uma partida, a partir do diretório `src/`:

```bash
swipl -l Interactor.prolog
```

```prolog
?- gameStart('cenarios/cenario2', 3, 'testes/agenteL3', 'detetive/detetive_marple', _, V), write(V), nl.
```

Para rodar várias partidas de uma vez:

```bash
swipl -q -f testes/batch_test.pl \
  -g "batch('cenarios/cenario2', 'testes/agenteL3', 'detetive/detetive_marple', 30), halt."
```

## Interface exportada

```prolog
:- module('detetive_marple', [detetive_action/3, detetive_preload/5]).
```

`detetive_preload(+G, +LS, +LI, +LT, -pronto)` inicializa a base de conhecimento interna do agente com o grafo, os suspeitos, os itens e os tesouros do cenário.

`detetive_action(+Events, +Estado, -Acao)` decide a ação do turno a partir dos eventos visíveis e do estado atual. `Events` é uma lista de `roubo(Item, Cidade, Pistas)` com o roubo mais recente na cabeça. `Estado` tem a forma `detective(loc(Cidade), Mandato, Pistas)`.

## Estratégia

O agente funciona como uma cascata de prioridades: a primeira regra que casa decide a ação do turno.

O raciocínio que guia tudo é que o ladrão obrigatoriamente entra na cidade do tesouro para roubá-lo e precisa sair de lá para vencer. Então, se a cidade certa estiver fechada no momento certo, qualquer tentativa de fuga vira captura, sem depender de mandato.

### Fechamento da cidade do tesouro

Logo no primeiro turno o detetive fecha a cidade do tesouro de cadeia mais curta. É o palpite mais razoável na ausência de informação, porque uma cadeia curta é a opção mais rápida para o ladrão e também a que gera menos eventos antes do roubo final (no limite, um tesouro sem pré-requisito não dá aviso nenhum). Como no motor `fechar(C)` substitui a cidade fechada anterior em uma única ação, errar o palpite não custa nada: dá pra trocar depois sem nunca deixar zero cidades fechadas, respeitando a regra de uma cidade por vez.

A troca acontece quando algum tesouro fica "pronto", ou seja, quando todos os seus pré-requisitos (menos ele mesmo) já apareceram nos eventos. Nesse ponto o fechamento migra para a cidade desse tesouro. Como o motor atrasa os eventos em uma rodada, reagir ao penúltimo item da cadeia absorve exatamente esse atraso e o fechamento chega antes da primeira chance de fuga. A checagem é feita por tesouro, então um item roubado de outra cadeia não engana o agente. Se mais de um tesouro estiver pronto ao mesmo tempo, vale o que tem evidência mais recente nos eventos.

### Mandato

Depois que o tesouro é roubado, o agente pede mandato usando as pistas reveladas mais tarde (posições altas da lista de aparência), que são as menos afetadas por disfarce. Isso cobre o caso do ladrão que rouba e fica parado na cidade fechada: só fechando, esse cenário terminaria em empate, e empate vale zero na competição. Com mandato, o detetive vai até a cidade e inspeciona.

A navegação usa BFS para achar o caminho mais curto no grafo. O fecho transitivo das dependências de cada tesouro é pré-calculado no `preload`.