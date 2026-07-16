-- Geracao do grafo em formato DOT (Graphviz) a partir da lista de
-- Registros produzida pelo Parser. Requisitos visuais do trabalho:
--
--   - arestas percorridas pelo ladrao em vermelho;
--   - arestas percorridas pelo detetive em azul (se os dois passaram
--     pela mesma aresta, saem duas arestas paralelas, uma de cada cor);
--   - cidades com evento de roubo em doublecircle com fundo dourado e
--     o item roubado no rotulo do no.
--
-- Todas as funcoes deste modulo sao puras.
module GeradorDot
  ( gerarDot
  ) where

import Tipos

-- Converte os registros do log no texto completo do arquivo .dot.
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

    -- Cidades marcadas com roubo (nos declarados explicitamente).
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
-- Extracao de dados dos registros
-- ---------------------------------------------------------------------

-- Movimentos bem-sucedidos de um agente: (origem, destino, turno).
-- O casamento de padroes no gerador da compreensao ja filtra so as
-- acoes move com status [OK].
movimentos :: Agente -> [Registro] -> [(String, String, Int)]
movimentos ag regs =
  [ (o, d, t) | RegistroAcao t ag' (Move o d) True <- regs, ag' == ag ]

-- Eventos de roubo: (cidade, item roubado).
roubos :: [Registro] -> [(String, String)]
roubos regs = [ (cidade, item) | RegistroRoubo item cidade <- regs ]

-- ---------------------------------------------------------------------
-- Agrupamentos
-- ---------------------------------------------------------------------

-- Agrupa os movimentos por aresta (origem, destino), preservando a
-- ordem da primeira ocorrencia no log e juntando os turnos em que a
-- aresta foi percorrida (ex.: c -> d nos turnos 16 e 20).
agruparArestas :: [(String, String, Int)] -> [((String, String), [Int])]
agruparArestas movs =
  [ (par, turnosDe par) | par <- arestasSemRepeticao ]
  where
    arestasSemRepeticao = semRepeticao [ (o, d) | (o, d, _) <- movs ]
    turnosDe (o, d)     = quickSortPor (<) [ t | (o', d', t) <- movs, o' == o, d' == d ]

-- Agrupa os roubos por cidade, juntando todos os itens roubados nela.
agruparRoubos :: [(String, String)] -> [(String, [String])]
agruparRoubos rs =
  [ (cidade, itensDe cidade) | cidade <- semRepeticao (map fst rs) ]
  where
    itensDe cidade = [ item | (c, item) <- rs, c == cidade ]

-- ---------------------------------------------------------------------
-- Funcoes auxiliares (recursao explicita com acumuladores)
-- ---------------------------------------------------------------------

-- Remove repeticoes de uma lista preservando a ordem da primeira
-- ocorrencia, com um acumulador dos elementos ja vistos (mesma ideia
-- do nub de Data.List).
semRepeticao :: Eq a => [a] -> [a]
semRepeticao = semRepeticaoAc []
  where
    semRepeticaoAc _ [] = []
    semRepeticaoAc vistos (x : xs)
      | x `elemC` vistos = semRepeticaoAc vistos xs
      | otherwise         = x : semRepeticaoAc (x : vistos) xs

    elemC _ []       = False
    elemC y (z : zs) = y == z || elemC y zs

-- Quicksort com comparador explicito: particiona a lista em menores e
-- nao-menores que o pivo e concatena os resultados recursivos.
quickSortPor :: (a -> a -> Bool) -> [a] -> [a]
quickSortPor _        []       = []
quickSortPor _        [x]      = [x]
quickSortPor menorQue (x : xs) =
     quickSortPor menorQue [ y | y <- xs, menorQue y x ]
  ++ [x]
  ++ quickSortPor menorQue [ y | y <- xs, not (menorQue y x) ]

-- Junta uma lista de strings intercalando um separador entre elas
-- (mesma ideia do intercalate de Data.List).
juntarCom :: String -> [String] -> String
juntarCom _   []       = ""
juntarCom _   [s]      = s
juntarCom sep (s : ss) = s ++ sep ++ juntarCom sep ss

-- ---------------------------------------------------------------------
-- Impressao das linhas DOT
-- ---------------------------------------------------------------------

-- No de cidade onde houve roubo, ex.:
--   e [shape=doublecircle, style=filled, fillcolor=gold, label="e\n(Roubo: cartao_cofre)"];
noRoubo :: (String, [String]) -> String
noRoubo (cidade, itens) =
  "    " ++ cidade
        ++ " [shape=doublecircle, style=filled, fillcolor=gold, label=\""
        ++ cidade ++ "\\n(Roubo: " ++ juntarCom ", " itens ++ ")\"];"

-- Aresta colorida com os turnos no rotulo, ex.:
--   c -> d [color="red", label="T16, T20"];
aresta :: String -> ((String, String), [Int]) -> String
aresta cor ((origem, destino), turnos) =
  "    " ++ origem ++ " -> " ++ destino
        ++ " [color=\"" ++ cor ++ "\", label=\""
        ++ juntarCom ", " (map (("T" ++) . show) turnos) ++ "\"];"
