-- Parsing do log do jogo. Todas as funcoes deste modulo sao puras:
-- recebem Strings e devolvem valores do tipo Registro. Linhas que nao
-- sao acoes nem eventos (estado final S = gSt(...), V = ..., linhas em
-- branco) sao simplesmente descartadas.
--
-- Formatos reconhecidos:
--   20 ladrao: move(c,d) [OK]                        (acao de um agente)
--   >>>> Evento roubo(cartao_cofre, e, [altura(180)]) (evento global)
module Parser
  ( parseLog
  , parseLinha
  ) where

import Data.Char (isDigit, isSpace)

import Tipos

-- Converte o conteudo completo do log em uma lista de registros:
-- quebra em linhas e mantem so as que o parser reconhece.
parseLog :: String -> [Registro]
parseLog = filtrarJust parseLinha . lines

-- Aplica uma funcao que pode falhar a cada elemento e mantem apenas os
-- resultados que deram certo (mesma ideia do mapMaybe de Data.Maybe).
filtrarJust :: (a -> Maybe b) -> [a] -> [b]
filtrarJust _ []       = []
filtrarJust f (x : xs) =
  case f x of
    Just y  -> y : filtrarJust f xs
    Nothing -> filtrarJust f xs

-- Interpreta uma unica linha do log.
parseLinha :: String -> Maybe Registro
parseLinha linha
  | take 4 l == ">>>>" = parseEvento (drop 4 l)
  | otherwise          = parseAcao l
  where
    l = trim linha

-- ---------------------------------------------------------------------
-- Eventos globais
-- ---------------------------------------------------------------------

-- Interpreta um evento global de roubo, ex.:
--   Evento roubo(cartao_cofre, e, [altura(180)])
-- O terceiro argumento (lista de pistas) nao e usado no grafo.
parseEvento :: String -> Maybe Registro
parseEvento resto =
  case words resto of
    ("Evento" : ws) -> do
      (nome, args) <- parseTermo (concat ws)
      case (nome, args) of
        ("roubo", item : cidade : _) -> Just (RegistroRoubo item cidade)
        _                            -> Nothing
    _ -> Nothing

-- ---------------------------------------------------------------------
-- Acoes de agentes
-- ---------------------------------------------------------------------

-- Interpreta uma linha de acao no formato:
--   <turno> <agente>: <acao> [OK]
parseAcao :: String -> Maybe Registro
parseAcao l =
  case words l of
    (numero : nomeAgente : resto)
      | not (null numero), all isDigit numero, not (null resto) -> do
          ag <- parseAgente nomeAgente
          let (ok, corpo) = separarStatus resto
          (nome, args) <- parseTermo (concat corpo)
          Just (RegistroAcao (read numero) ag (termoParaAcao nome args) ok)
    _ -> Nothing

-- Reconhece o nome do agente (com o ':' no final).
parseAgente :: String -> Maybe Agente
parseAgente w =
  case takeWhile (/= ':') w of
    "ladrao"   -> Just Ladrao
    "detetive" -> Just Detetive
    _          -> Nothing

-- Separa o marcador de status ([OK], [FALHA], ...) do corpo da acao.
-- Devolve se a acao teve sucesso e as palavras restantes.
-- O marcador pode vir como palavra separada ("move(c,d) [OK]") ou
-- colado no fim da acao ("move(c,d)[OK]"); os dois casos aparecem nos
-- logs do jogo.
separarStatus :: [String] -> (Bool, [String])
separarStatus ws =
  case reverse ws of
    (ultimo : anteriores)
      | ehStatus ultimo -> (ultimo == "[OK]", reverse anteriores)
      | Just (corpo, status) <- separarSufixoStatus ultimo ->
          (status == "[OK]", reverse (corpo : anteriores))
    _                   -> (True, ws) -- sem marcador: assume sucesso
  where
    ehStatus w = take 1 w == "[" && take 1 (reverse w) == "]"

-- Destaca um status colado no fim da palavra:
--   "move(c,b)[OK]"  ->  Just ("move(c,b)", "[OK]")
-- O trecho entre os colchetes finais nao pode conter colchetes nem
-- parenteses, para nao confundir com um argumento-lista de verdade
-- (ex.: "disfarce([omitir(x)])" nao e dividido).
separarSufixoStatus :: String -> Maybe (String, String)
separarSufixoStatus w =
  case reverse w of
    (']' : resto) ->
      case break (== '[') resto of
        (interno, '[' : corpoInv)
          | not (null corpoInv), all (`notElem` "[]()") interno ->
              Just (reverse corpoInv, '[' : reverse interno ++ "]")
        _ -> Nothing
    _ -> Nothing

-- Converte um termo ja separado em functor e argumentos para Acao,
-- usando casamento de padroes para distinguir cada comando.
termoParaAcao :: String -> [String] -> Acao
termoParaAcao "move"   [origem, destino] = Move origem destino
termoParaAcao "roubar" [item]            = Roubar item
termoParaAcao "fechar" [cidade]          = Fechar cidade
termoParaAcao "nada"   []                = Nada
termoParaAcao nome     _                 = Outra nome

-- ---------------------------------------------------------------------
-- Parsing de termos no estilo Prolog: functor(arg1, arg2, ...)
-- ---------------------------------------------------------------------

-- Separa um termo em functor e lista de argumentos de nivel superior:
--   parseTermo "move(c,d)"  ==  Just ("move", ["c","d"])
--   parseTermo "nada"       ==  Just ("nada", [])
parseTermo :: String -> Maybe (String, [String])
parseTermo s =
  case break (== '(') s of
    ("", _)         -> Nothing
    (nome, "")      -> Just (nome, [])
    (nome, '(' : resto)
      | not (null resto), last resto == ')' ->
          let interno = init resto
          in if null (trim interno)
               then Just (nome, [])
               else Just (nome, map trim (separarArgs interno))
    _               -> Nothing

-- Divide uma lista de argumentos pelas virgulas de nivel superior,
-- respeitando parenteses e colchetes aninhados (ex.:
-- "cartao_cofre,e,[altura(180)]" tem tres argumentos). Implementada
-- com recursao, carregando a profundidade como acumulador.
separarArgs :: String -> [String]
separarArgs = go (0 :: Int) ""
  where
    go _ atual []       = [reverse atual]
    go n atual (c : cs)
      | c == ',' && n == 0   = reverse atual : go 0 "" cs
      | c == '(' || c == '[' = go (n + 1) (c : atual) cs
      | c == ')' || c == ']' = go (n - 1) (c : atual) cs
      | otherwise            = go n (c : atual) cs

-- Remove espacos em branco das duas extremidades.
trim :: String -> String
trim = dropWhile isSpace . dropWhileFim isSpace

-- Remove do final da string os caracteres que satisfazem o predicado
-- (mesma ideia do dropWhileEnd de Data.List).
dropWhileFim :: (Char -> Bool) -> String -> String
dropWhileFim p = reverse . dropWhile p . reverse
