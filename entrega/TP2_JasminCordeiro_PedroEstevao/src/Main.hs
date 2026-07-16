-- Trabalho Pratico 2 - CSI107 Linguagens de Programacao (DECSI/UFOP)
-- Converte o log de uma partida do jogo "Detetive x Ladrao" (TP1)
-- em um grafo no formato DOT (Graphviz).
--
-- Autores:
--   Jasmin Andrade Cordeiro       - 22.2.8104
--   Pedro Henrique Amaral Estevao - 22.1.8079
--
-- Todo o I/O do programa fica neste modulo. Parser e GeradorDot sao
-- puros, entao a conversao inteira se resume a gerarDot . parseLog.
--
-- Uso:
--   log2dot entrada.log saida.dot
--   log2dot entrada.log            (imprime o .dot na saida padrao)
--   log2dot                        (filtro: entrada padrao -> saida padrao)
module Main (main) where

import System.Environment (getArgs, getProgName)
import System.Exit (exitFailure)
import System.IO (hPutStrLn, stderr)

import GeradorDot (gerarDot)
import Parser (parseLog)

-- Nucleo puro da conversao: texto do log -> texto do grafo DOT.
converter :: String -> String
converter = gerarDot . parseLog

-- Unica funcao com efeitos de entrada e saida.
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
