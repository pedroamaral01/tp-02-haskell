-- |
-- Módulo      : Parser
-- Descrição   : Parsing puro do log gerado pelo jogo "Detetive x Ladrão".
--
-- Todas as funções deste módulo são puras: recebem 'String's e devolvem
-- valores imutáveis do tipo 'Registro'. Linhas que não representam ações
-- nem eventos (estado final @S = gSt(...)@, @V = ...@, linhas em branco)
-- são simplesmente descartadas, o que torna o parser robusto.
--
-- Formatos reconhecidos:
--
-- > 20 ladrao: move(c,d) [OK]              (ação de um agente em um turno)
-- > >>>> Evento roubo(cartao_cofre, e, [altura(180)])   (evento global)
module Parser
  ( parseLog
  , parseLinha
  ) where

import Data.Char (isDigit, isSpace)
import Data.List (dropWhileEnd)
import Data.Maybe (mapMaybe)

import Tipos

-- | Converte o conteúdo completo do log em uma lista de registros.
--
-- Composição de funções de alta ordem: quebra o texto em linhas e
-- mantém apenas as que o parser reconhece ('mapMaybe').
parseLog :: String -> [Registro]
parseLog = mapMaybe parseLinha . lines

-- | Interpreta uma única linha do log.
parseLinha :: String -> Maybe Registro
parseLinha linha
  | take 4 l == ">>>>" = parseEvento (drop 4 l)
  | otherwise          = parseAcao l
  where
    l = trim linha

-- ---------------------------------------------------------------------
-- Eventos globais
-- ---------------------------------------------------------------------

-- | Interpreta um evento global de roubo, ex.:
--
-- > Evento roubo(cartao_cofre, e, [altura(180)])
--
-- O terceiro argumento (lista de pistas) não é usado no grafo.
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
-- Ações de agentes
-- ---------------------------------------------------------------------

-- | Interpreta uma linha de ação no formato:
--
-- > <turno> <agente>: <acao> [OK]
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

-- | Reconhece o nome do agente (com o @:@ ao final).
parseAgente :: String -> Maybe Agente
parseAgente w =
  case takeWhile (/= ':') w of
    "ladrao"   -> Just Ladrao
    "detetive" -> Just Detetive
    _          -> Nothing

-- | Separa o marcador de status (@[OK]@, @[FALHA]@, ...) do corpo da ação.
-- Devolve se a ação teve sucesso e as palavras restantes.
separarStatus :: [String] -> (Bool, [String])
separarStatus ws =
  case reverse ws of
    (ultimo : anteriores)
      | ehStatus ultimo -> (ultimo == "[OK]", reverse anteriores)
    _                   -> (True, ws) -- sem marcador: assume sucesso
  where
    ehStatus w = take 1 w == "[" && take 1 (reverse w) == "]"

-- | Converte um termo já separado em functor e argumentos para 'Acao',
-- usando casamento de padrões para distinguir cada comando.
termoParaAcao :: String -> [String] -> Acao
termoParaAcao "move"   [origem, destino] = Move origem destino
termoParaAcao "roubar" [item]            = Roubar item
termoParaAcao "fechar" [cidade]          = Fechar cidade
termoParaAcao "nada"   []                = Nada
termoParaAcao nome     _                 = Outra nome

-- ---------------------------------------------------------------------
-- Parsing de termos no estilo Prolog: functor(arg1, arg2, ...)
-- ---------------------------------------------------------------------

-- | Separa um termo em functor e lista de argumentos de nível superior.
--
-- >>> parseTermo "move(c,d)"
-- Just ("move", ["c","d"])
--
-- >>> parseTermo "nada"
-- Just ("nada", [])
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

-- | Divide uma lista de argumentos pelas vírgulas de nível superior,
-- respeitando parênteses e colchetes aninhados
-- (ex.: @\"cartao_cofre,e,[altura(180)]\"@ tem três argumentos).
--
-- Implementada com recursão e um acumulador de profundidade,
-- sem qualquer estado mutável.
separarArgs :: String -> [String]
separarArgs = go (0 :: Int) ""
  where
    go _ atual []       = [reverse atual]
    go n atual (c : cs)
      | c == ',' && n == 0   = reverse atual : go 0 "" cs
      | c == '(' || c == '[' = go (n + 1) (c : atual) cs
      | c == ')' || c == ']' = go (n - 1) (c : atual) cs
      | otherwise            = go n (c : atual) cs

-- | Remove espaços em branco das duas extremidades.
trim :: String -> String
trim = dropWhile isSpace . dropWhileEnd isSpace
