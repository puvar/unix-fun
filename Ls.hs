module Main where

import Control.Applicative
import Control.Monad
import Data.List
import System.Console.GetOpt
import System.Directory
import System.Environment
import System.FilePath
import System.IO
import System.Posix.Files
import Text.Printf

data Flag
  = FlagA
  | FlagL
  deriving (Eq)

getOptions :: IO ([Flag], [String])
getOptions = do
  args <- getArgs
  case getOpt RequireOrder options args of
    (flags, filepaths, []) -> return (flags, filepaths)
    (_, _, errs) ->
      ioError (userError (concat errs ++ usageInfo header options))
  where
    header = "Usage: cat [OPTION]... [FILE]..."
    options =
      [ Option "l" ["long"] (NoArg FlagL) "List in long format."
      , Option
          "a"
          ["all"]
          (NoArg FlagA)
          "Include directory entries whose names begin with a dot (.)."
      ]

cmpFunc :: [Flag] -> (FilePath, FileStatus) -> (FilePath, FileStatus) -> Ordering
cmpFunc flags (name1, status1) (name2, status2) =
  compare name1 name2

lsItems :: [Flag] -> [(FilePath, FileStatus)] -> IO ()
lsItems flags items' = do
  let items = filter itemFilter items'
  let sortedItems = sortBy (cmpFunc flags) items
  forM_ sortedItems (\(na, st) -> printf "%s\n" na)
  where
    itemFilter =
      if FlagA `elem` flags
        then (\_ -> True)
        else (\(name, _) -> head name /= '.')

lsDir :: [Flag] -> FilePath -> IO ()
lsDir flags dirpath = do
  names <- getDirectoryContents dirpath
  statuses <- sequence [getFileStatus (dirpath </> name) | name <- names]
  let items = zip names statuses
  lsItems flags items

main :: IO ()
main = do
  (flags, filepaths) <- getOptions
  let names =
        if null filepaths
          then ["."]
          else filepaths
  statuses <- sequence [getFileStatus name | name <- names]
  let nast = sortBy (cmpFunc flags) $ zip names statuses
  let (dirs, files) = partition (\(na, st) -> isDirectory st) nast
  lsItems flags files
  if length files > 0 && length dirs > 0 then printf "\n" else return ()
  forM_ dirs 
    (\(na, st) -> do
      if length nast > 0
        then printf "%s:\n" na
        else return ()
      lsDir flags na)