% Trabalho Pratico - CSI107 Linguagens de Programacao (DECSI/UFOP)
% Agente detetive
% Jasmin Andrade Cordeiro 22.2.8104
% Pedro Henrique Amaral Estevao 22.1.8079
%
% Estrategia: o ladrao precisa entrar na cidade do tesouro para roubar
% e sair dela para vencer, entao manter a cidade certa fechada na hora
% certa captura qualquer ladrao que tente fugir, sem precisar de mandato.
% Contra o ladrao que rouba e nao foge, mandato tardio + inspecionar.

:- module('detetive_marple', [detetive_action/3, detetive_preload/5]).

:- dynamic adj/2.
:- dynamic suspeito/2.
:- dynamic itemJogo/3.
:- dynamic tesouroJogo/3.
:- dynamic fechoTesouro/2.
:- dynamic fechada/1.

% preload: copia os dados publicos do cenario para a base local e
% pre-calcula o fecho transitivo das dependencias de cada tesouro

detetive_preload(G, LS, LI, LT, pronto) :-
    retractall(adj(_,_)),
    retractall(suspeito(_,_)),
    retractall(itemJogo(_,_,_)),
    retractall(tesouroJogo(_,_,_)),
    retractall(fechoTesouro(_,_)),
    retractall(fechada(_)),
    forall(member(adj(A,B), G), (assertz(adj(A,B)), assertz(adj(B,A)))),
    forall(member(procurado(ID,AP), LS), assertz(suspeito(ID,AP))),
    forall(member(item(N,C,XS), LI), assertz(itemJogo(N,C,XS))),
    forall(member(tesouro(N,C,XS), LT), assertz(tesouroJogo(N,C,XS))),
    forall(tesouroJogo(T,_,_), (fecho(T,Deps), assertz(fechoTesouro(T,Deps)))).

detetive_action(EV, detective(loc(C), M, _), A) :- decidir(EV, C, M, A).

% decisao em cascata: a primeira clausula que casa vale (corte)

% P1: fecha (ou troca o lock para) a cidade do tesouro "pronto", aquele
% cujos pre-requisitos ja apareceram todos nos eventos. O motor atrasa
% os eventos em 1 rodada, entao reagir ao penultimo item da cadeia
% garante o fechamento antes da primeira chance de fuga:
%   ladrao rouba o penultimo item em C (evento pendente)
%   detetive ainda nao ve o evento
%   ladrao rouba o tesouro (continua em C, roubar nao move)
%   detetive ve o penultimo item e fecha C
%   ladrao tenta sair de C e e capturado
% A checagem e por tesouro, entao item-isca de outra cadeia nao entra
% na conta. No motor corrigido fechar(C) substitui o lock atual numa
% acao so, sem turno com zero cidades fechadas.
decidir(EV, _, _, fechar(C)) :-
    \+ ladraoPreso(EV),
    itensRoubados(EV, XS), XS \= [],
    melhorAlvo(EV, XS, T),
    tesouroJogo(T, C, _),
    \+ fechada(C),
    retractall(fechada(_)), assertz(fechada(C)), !.

% P1b: lock de abertura. Enquanto nenhum tesouro esta pronto, vale
% fechar a cidade-palpite: se o palpite errar, a troca pelo P1 sai de
% graca. Cobre o tesouro sem pre-requisito, que nao da aviso nenhum.
decidir(_, _, _, fechar(C)) :-
    \+ fechada(_),
    cidadePalpite(C),
    assertz(fechada(C)), !.

% P2: tesouro roubado, tenho mandato e estou na cidade do ladrao
decidir(EV, C, mandato(_), inspecionar) :-
    tesouroRoubado(EV),
    cidadeUltimoRoubo(EV, C), !.

% P3: tesouro roubado, tenho mandato, caminho ate o ladrao
decidir(EV, C, mandato(_), move(C, Prox)) :-
    tesouroRoubado(EV),
    cidadeUltimoRoubo(EV, Alvo), Alvo \= C,
    proximoPasso(C, Alvo, Prox), Prox \= C, !.

% P4: mandato tardio, so depois do roubo do tesouro. O mandato e
% one-shot (o motor so aceita com mandato nenhum), um pedido errado
% trava para sempre, entao pedimos com informacao maxima.
decidir(EV, _, nenhum, pedir_mandato(ID, Sub)) :-
    tesouroRoubado(EV),
    montarMandato(EV, ID, Sub), !.

% P5: antes do heist, segue a cidade do ultimo roubo
decidir(EV, C, _, move(C, Prox)) :-
    cidadeUltimoRoubo(EV, Alvo), Alvo \= C,
    proximoPasso(C, Alvo, Prox), Prox \= C, !.

% P6: sem eventos ainda, caminha para a cidade-tesouro de maior cadeia
decidir(_, C, _, move(C, Prox)) :-
    cidadeEstrategica(Alvo),
    proximoPasso(C, Alvo, Prox), Prox \= C, !.

decidir(_, _, _, nada).

% eventos de roubo (o mais recente fica na cabeca da lista)

cidadeUltimoRoubo([roubo(_,C,_)|_], C) :- !.

tesouroRoubado(EV) :- member(roubo(I,_,_), EV), tesouroJogo(I,_,_), !.

itensRoubados(EV, XS) :- findall(I, member(roubo(I,_,_), EV), XS).

% depois do heist, se o ladrao esta preso na cidade fechada o lock nao
% troca mais (trocar seria solta-lo)
ladraoPreso(EV) :-
    tesouroRoubado(EV),
    cidadeUltimoRoubo(EV, C),
    fechada(C).

% tesouro pronto: todos os pre-requisitos (fecho menos ele mesmo) ja
% roubados. Cadeia vazia fica de fora: sem evento nao ha evidencia,
% e o caso e coberto pelo lock de abertura.
tesouroPronto(XS, T) :-
    fechoTesouro(T, Deps),
    subtract(Deps, [T], Pre),
    Pre \= [],
    forall(member(P, Pre), member(P, XS)).

% entre os tesouros prontos vence o de evidencia mais recente nos
% eventos (menor indice = evento mais novo)
melhorAlvo(EV, XS, T) :-
    findall(R-T1,
        ( tesouroPronto(XS, T1),
          fechoTesouro(T1, Deps),
          subtract(Deps, [T1], Pre),
          posEvidencia(EV, Pre, R) ),
        RS),
    RS \= [],
    keysort(RS, [_-T|_]).

posEvidencia(EV, Pre, R) :- nth0(R, EV, roubo(P,_,_)), memberchk(P, Pre), !.

% mandato robusto a disfarce: o disfarce afeta os primeiros atributos
% revelados, entao as pistas de posicao alta sao as mais confiaveis.
% Le a ordem das revelacoes nos eventos (nao o conjunto achatado de
% pistas) e confia no sufixo da revelacao mais rica.

montarMandato(EV, ID, Sub) :-
    maiorRevelacao(EV, R),
    pistasValidas(R, RV), RV \= [],
    reverse(RV, Conf),
    ( mandatoPrefixo(Conf, ID, Sub)
    ; mandatoSubconjunto(RV, ID, Sub) ), !.

% revelacao mais rica = a sublista de pistas mais longa dos eventos
maiorRevelacao(EV, R) :-
    findall(L-P, (member(roubo(_,_,P), EV), length(P, L)), PS),
    PS \= [],
    sort(0, @>=, PS, [_-R|_]).

% descarta 'none' e atributo que nenhum suspeito possui
pistasValidas([], []).
pistasValidas([C|CS], [C|RV]) :- algumSuspeitoTem(C), !, pistasValidas(CS, RV).
pistasValidas([_|CS], RV) :- pistasValidas(CS, RV).

algumSuspeitoTem(C) :- suspeito(_, aparencia(AS)), memberchk(C, AS), !.

% menor prefixo das pistas confiaveis que reduz os suspeitos a <= 2;
% entre os sobreviventes pede pelo menor ID
mandatoPrefixo(Conf, ID, Sub) :-
    length(Conf, Max),
    between(1, Max, N),
    length(Sub, N),
    append(Sub, _, Conf),
    suspeitosCompativeis(Sub, IDs),
    length(IDs, K), K >= 1, K =< 2, !,
    min_list(IDs, ID).

% fallback: menor subconjunto qualquer das pistas validas. Teto de 6
% pistas porque a busca por subconjunto e combinatoria.
mandatoSubconjunto(RV, ID, Sub) :-
    length(RV, L),
    Max is min(L, 6),
    between(1, Max, N),
    length(Sub, N),
    subconjunto(Sub, RV),
    ground(Sub),
    suspeitosCompativeis(Sub, IDs),
    length(IDs, K), K >= 1, K =< 2, !,
    min_list(IDs, ID).

suspeitosCompativeis(AS, IDs) :-
    findall(ID, (suspeito(ID, aparencia(XS)), todosEm(AS, XS)), IDs).

todosEm([], _).
todosEm([X|XS], YS) :- member(X, YS), !, todosEm(XS, YS).

subconjunto([], _).
subconjunto([X|XS], YS) :- select(X, YS, Resto), subconjunto(XS, Resto).

% palpite de abertura: tesouro de cadeia mais curta, que e o alvo mais
% barato para o ladrao e o que da menos aviso previo ao detetive
cidadePalpite(C) :-
    findall(K-C1, (fechoTesouro(T,Deps), length(Deps,K), tesouroJogo(T,C1,_)), PS),
    PS \= [],
    msort(PS, [_-C|_]), !.
cidadePalpite(C) :- tesouroJogo(_, C, _), !.

% posicionamento inicial: tesouro de cadeia mais longa (mais itens da
% cadeia por perto, mais chance de cruzar com o ladrao)
cidadeEstrategica(C) :-
    findall(K-C1, (fechoTesouro(T,Deps), length(Deps,K), tesouroJogo(T,C1,_)), PS),
    PS \= [],
    msort(PS, SS),
    last(SS, _-C), !.
cidadeEstrategica(C) :- tesouroJogo(_, C, _), !.

% caminho mais curto por BFS. A busca nativa do prolog e em
% profundidade e devolveria o primeiro caminho, nao o menor.

proximoPasso(X, X, X) :- !.
proximoPasso(De, Ate, Prox) :-
    bfs([[De]], Ate, Rev),
    reverse(Rev, [De, Prox|_]), !.
proximoPasso(De, _, De).

bfs([[Alvo|Resto]|_], Alvo, [Alvo|Resto]) :- !.
bfs([[C|Vis]|Fila], Alvo, Cam) :-
    findall([V,C|Vis], (adj(C,V), \+ member(V,[C|Vis])), Novos),
    append(Fila, Novos, Fila1),
    Fila1 \= [],
    bfs(Fila1, Alvo, Cam).

% fecho transitivo das dependencias de um item/tesouro

fecho(Nome, Deps) :- fecho_aux([Nome], [], Deps).

fecho_aux([], Acc, Acc) :- !.
fecho_aux([X|XS], Vis, Res) :-
    ( member(X, Vis) -> fecho_aux(XS, Vis, Res)
    ; ( itemJogo(X,_,Reqs)    -> true
      ; tesouroJogo(X,_,Reqs) -> true
      ; Reqs = [] ),
      append(XS, Reqs, Fila),
      fecho_aux(Fila, [X|Vis], Res)
    ).
