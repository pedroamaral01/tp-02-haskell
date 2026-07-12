-- |
-- Módulo      : Main
-- Descrição   : Ponto de entrada — todo o I/O do programa vive aqui.
--
-- Trabalho Prático de CSI107 (Linguagens de Programação, DECSI/UFOP):
-- converte o log de uma partida do jogo "Detetive x Ladrão" em um grafo
-- no formato DOT (Graphviz).
--
-- O efeito colateral (leitura do log e escrita do @.dot@) fica isolado
-- nesta função monádica; o núcleo do programa ("Parser" e "GeradorDot")
-- é composto apenas por funções puras, e a conversão inteira se resume
-- à composição @gerarDot . parseLog@.
--
-- Uso:
--
-- > log2dot <entrada.log> <saida.dot>   -- lê e grava arquivos
-- > log2dot <entrada.log>               -- imprime o .dot na saída padrão
-- > log2dot                             -- filtro: entrada padrão -> saída padrão
module Main (main) where

import System.Environment (getArgs, getProgName)
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)

import GeradorDot (gerarDot)
import Parser (parseLog)

-- | Núcleo puro da conversão: texto do log -> texto do grafo DOT.
converter :: String -> String
converter = gerarDot . parseLog

-- | Função principal: única responsável por efeitos de entrada e saída.
main :: IO ()
main = do
  args <- getArgs
  case args of
    [entrada, saida] -> do
      conteudo <- readFile entrada
      writeFile saida (converter conteudo)
      putStrLn ("Grafo gerado em: " ++ saida)
    [entrada] -> do
      conteudo <- readFile entrada
      putStr (converter conteudo)
    [] -> interact converter
    _ -> do
      nome <- getProgName
      hPutStrLn stderr ("Uso: " ++ nome ++ " <entrada.log> [saida.dot]")
      exitFailure
