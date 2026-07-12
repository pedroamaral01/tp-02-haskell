-- |
-- Módulo      : Tipos
-- Descrição   : Tipos de dados centrais da ferramenta de auditoria visual.
--
-- Este módulo define a representação imutável de um log do jogo
-- "Detetive x Ladrão": cada linha relevante do arquivo de entrada é
-- convertida em um valor do tipo 'Registro'.
module Tipos
  ( Agente (..)
  , Acao (..)
  , Registro (..)
  ) where

-- | Os dois agentes que aparecem no log do jogo.
data Agente
  = Ladrao
  | Detetive
  deriving (Eq, Show)

-- | Ação executada por um agente em um turno.
--
-- As ações que não influenciam o grafo (ex.: @pedir_mandato@,
-- @inspecionar@) são preservadas de forma genérica em 'Outra',
-- o que torna o parser tolerante a extensões do jogo.
data Acao
  = Move String String -- ^ @move(origem, destino)@
  | Roubar String      -- ^ @roubar(item)@
  | Fechar String      -- ^ @fechar(cidade)@
  | Nada               -- ^ @nada@
  | Outra String       -- ^ qualquer outra ação (apenas o nome do functor)
  deriving (Eq, Show)

-- | Uma linha relevante do log já interpretada.
data Registro
  = RegistroAcao Int Agente Acao Bool
    -- ^ turno, agente, ação executada e se terminou com @[OK]@
  | RegistroRoubo String String
    -- ^ evento global de roubo: item roubado e cidade onde ocorreu
  deriving (Eq, Show)
