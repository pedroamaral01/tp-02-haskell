-- |
-- Módulo      : GeradorDot
-- Descrição   : Geração pura do grafo em formato DOT (Graphviz).
--
-- A partir da lista de 'Registro's produzida pelo "Parser", este módulo
-- monta a 'String' final do arquivo @.dot@, cumprindo os requisitos
-- visuais do trabalho:
--
--   * arestas percorridas pelo ladrão em __vermelho__;
--   * arestas percorridas pelo detetive em __azul__
--     (arestas compartilhadas aparecem em paralelo, uma de cada cor);
--   * cidades com evento de roubo destacadas com @doublecircle@,
--     fundo dourado e o item roubado no rótulo do nó.
--
-- Todas as funções são puras; nenhum estado é modificado.
module GeradorDot
  ( gerarDot
  ) where

import Tipos

-- | Ponto de entrada do módulo: converte os registros do log no texto
-- completo do arquivo @.dot@.
gerarDot :: [Registro] -> String
gerarDot regs =
  unlines $
       cabecalho
    ++ secaoRoubos
    ++ secaoAgente "Caminho do Ladrao (vermelho)" "red" Ladrao
    ++ secaoAgente "Caminho do Detetive (azul)" "blue" Detetive
    ++ ["}"]
  where
    cabecalho =
      [ "digraph JogoDetetiveLadrao {"
      , "    // Definicoes globais"
      , "    node [shape=circle];"
      , ""
      ]

    -- Cidades marcadas com roubo (nós declarados explicitamente).
    secaoRoubos =
      case agruparRoubos (roubos regs) of
        []  -> []
        rs  -> "    // Cidades onde ocorreram roubos"
               : map noRoubo rs ++ [""]

    -- Arestas percorridas por um agente, agrupadas e coloridas.
    secaoAgente titulo cor ag =
      case agruparArestas (movimentos ag regs) of
        [] -> [ "    // " ++ titulo ++ ": sem movimentos", "" ]
        as -> ("    // " ++ titulo)
              : map (aresta cor) as ++ [""]

-- ---------------------------------------------------------------------
-- Extração de dados dos registros (filtros por casamento de padrões)
-- ---------------------------------------------------------------------

-- | Movimentos bem-sucedidos de um agente: (origem, destino, turno).
-- O casamento de padrões no gerador da compreensão de lista já filtra
-- somente as ações @move@ com status @[OK]@.
movimentos :: Agente -> [Registro] -> [(String, String, Int)]
movimentos ag regs =
  [ (o, d, t) | RegistroAcao t ag' (Move o d) True <- regs, ag' == ag ]

-- | Eventos de roubo: (cidade, item roubado).
roubos :: [Registro] -> [(String, String)]
roubos regs = [ (cidade, item) | RegistroRoubo item cidade <- regs ]

-- ---------------------------------------------------------------------
-- Agrupamentos (funções puras, sem estruturas mutáveis)
-- ---------------------------------------------------------------------

-- | Agrupa os movimentos por aresta (origem, destino), preservando a
-- ordem da primeira ocorrência no log e reunindo os turnos em que a
-- aresta foi percorrida (ex.: @c -> d@ nos turnos 16 e 20).
agruparArestas :: [(String, String, Int)] -> [((String, String), [Int])]
agruparArestas movs =
  [ (par, turnosDe par) | par <- arestasSemRepeticao ]
  where
    arestasSemRepeticao = semRepeticao [ (o, d) | (o, d, _) <- movs ]
    turnosDe (o, d)     = quickSortPor (<) [ t | (o', d', t) <- movs, o' == o, d' == d ]

-- | Agrupa os roubos por cidade, reunindo todos os itens roubados nela.
agruparRoubos :: [(String, String)] -> [(String, [String])]
agruparRoubos rs =
  [ (cidade, itensDe cidade) | cidade <- semRepeticao (map fst rs) ]
  where
    itensDe cidade = [ item | (c, item) <- rs, c == cidade ]

-- ---------------------------------------------------------------------
-- Funções auxiliares (recursão explícita com acumuladores)
-- ---------------------------------------------------------------------

-- | Remove repetições de uma lista preservando a ordem da primeira
-- ocorrência, usando recursão com um acumulador dos elementos já vistos.
semRepeticao :: Eq a => [a] -> [a]
semRepeticao = semRepeticaoAc []
  where
    semRepeticaoAc _ [] = []
    semRepeticaoAc vistos (x : xs)
      | x `elemC` vistos = semRepeticaoAc vistos xs
      | otherwise         = x : semRepeticaoAc (x : vistos) xs

    elemC _ []       = False
    elemC y (z : zs) = y == z || elemC y zs

-- | Ordenação por comparador explícito (quicksort): particiona a lista
-- em menores e não-menores que o pivô e concatena os resultados
-- recursivos.
quickSortPor :: (a -> a -> Bool) -> [a] -> [a]
quickSortPor _        []       = []
quickSortPor _        [x]      = [x]
quickSortPor menorQue (x : xs) =
     quickSortPor menorQue [ y | y <- xs, menorQue y x ]
  ++ [x]
  ++ quickSortPor menorQue [ y | y <- xs, not (menorQue y x) ]

-- | Junta uma lista de strings intercalando um separador entre elas
-- (equivalente a 'Data.List.intercalate').
juntarCom :: String -> [String] -> String
juntarCom _   []       = ""
juntarCom _   [s]      = s
juntarCom sep (s : ss) = s ++ sep ++ juntarCom sep ss

-- ---------------------------------------------------------------------
-- Impressão das linhas DOT
-- ---------------------------------------------------------------------

-- | Nó de cidade onde houve roubo, ex.:
--
-- > e [shape=doublecircle, style=filled, fillcolor=gold, label="e\n(Roubo: cartao_cofre)"];
noRoubo :: (String, [String]) -> String
noRoubo (cidade, itens) =
  "    " ++ cidade
        ++ " [shape=doublecircle, style=filled, fillcolor=gold, label=\""
        ++ cidade ++ "\\n(Roubo: " ++ juntarCom ", " itens ++ ")\"];"

-- | Aresta colorida com os turnos no rótulo, ex.:
--
-- > c -> d [color="red", label="T16, T20"];
aresta :: String -> ((String, String), [Int]) -> String
aresta cor ((origem, destino), turnos) =
  "    " ++ origem ++ " -> " ++ destino
        ++ " [color=\"" ++ cor ++ "\", label=\""
        ++ juntarCom ", " (map (("T" ++) . show) turnos) ++ "\"];"
