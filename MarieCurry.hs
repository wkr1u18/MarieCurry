
    import Control.Exception
    import System.Environment
    import System.IO
    import MCLexer
    import MCParser
    import TypeCheck
    import Eval
    import Preprocesor

    makeStrict (a, b) = seq a (seq b (a, b))


    runChecker :: Stmt -> (Code, Type)
    runChecker input = makeStrict (convert input, check input [])

    getFilename :: IO (String)
    getFilename = do
        path <- getArgs
        if (path==[]) 
        then 
          return ("")
        else
          return (head path)

    stdError :: String -> IO ()
    stdError string = hPutStrLn stderr string

    main :: IO ()
    main = do
        file <- getFilename
        processed <- runPreprocesor file
        catch (runProgram $ fst $ runChecker $ processed) handler
          where
            handler :: SomeException -> IO ()
            handler ex = stdError $ show ex
