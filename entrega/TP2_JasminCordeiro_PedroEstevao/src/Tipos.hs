-- Tipos de dados do programa. Cada linha relevante do log de entrada
-- vira um valor do tipo Registro.
module Tipos
  ( Agente (..)
  , Acao (..)
  , Registro (..)
  ) where

-- Os dois agentes que aparecem no log do jogo.
data Agente
  = Ladrao
  | Detetive
  deriving (Eq, Show)

-- Acao executada por um agente em um turno. Acoes que nao afetam o
-- grafo (pedir_mandato, inspecionar, disfarce, ...) caem no construtor
-- Outra, guardando so o nome, o que deixa o parser tolerante a acoes
-- novas do jogo.
data Acao
  = Move String String -- move(origem, destino)
  | Roubar String      -- roubar(item)
  | Fechar String      -- fechar(cidade)
  | Nada               -- nada
  | Outra String       -- qualquer outra acao (apenas o nome)
  deriving (Eq, Show)

-- Uma linha do log ja interpretada.
data Registro
  = RegistroAcao Int Agente Acao Bool
    -- turno, agente, acao e se terminou com [OK]
  | RegistroRoubo String String
    -- evento global de roubo: item roubado e cidade onde ocorreu
  deriving (Eq, Show)
