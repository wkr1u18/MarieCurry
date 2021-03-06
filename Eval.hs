module Eval(runProgram, convert, Code) where

--e ::= v | x | e op e
--    | while (e) e | if (e) then e else e
--    | var x = e; e | x = e | e; e
--    | v
--v ::= n | true | false | loc

import qualified Data.Map as Map
import Data.List
import System.IO (isEOF, hPutStrLn, stderr)
import Data.Bits(xor)
import Control.Monad
import Debug.Trace
import MCParser
import MCLexer

type Environment = Map.Map String Address
type Store = Map.Map Address Code
type Address = Int
type Buffer = [[Int]]

data ExceptionCodeType =
      NullPointerException
    | StreamsNotInitialisedException
    | NotExistingStreamConsumptionException
    | DivideByZeroException
    | TrapException
    | ListEmptyException
         deriving (Eq, Show)

data UnaryOpType =
              Negate
            | LogicalNot
            | Head
            | Tail
            | ListIsEmpty
            | FstOp
            | SndOp
                deriving (Eq, Show)

data OpType =
              Add
            | Multiply
            | Subtract
            | Divide
            | Modulo
            | LessThan
            | LessOrEqual
            | Equal
            | NotEqual
            | GreaterOrEqual
            | GreaterThan
            | LogicalAnd
            | LogicalXor
            | LogicalOr
            | ListCons
                 deriving (Eq, Show)


data Code =   Null
            | Void
            | Exception ExceptionCodeType
            | Number Int
            | Boolean Bool
            | Character Char
            | Location Address
            | Reference String
            | While Code Code
            | If Code Code Code
            | Definition String
            | Assignment String Code
            | Statement Code Code
            | InitStreams Int
            | Consume Code
            | Print Code
            | Throw ExceptionCodeType
            | TryCatch ExceptionCodeType Code Code
            | BinOp OpType Code Code
            | UnaryOp UnaryOpType Code
            | Lam String Code
            | Closure String Code Environment
            | App Code Code
            | Unit
            | List ListContents
            | Pair Code Code
                deriving (Show, Eq)

data Frame =  Branch Code Code Environment
            | Then Code Environment
            | EvalRight OpType Code Environment
            | EvalOp OpType Code Environment
            | Assign String Environment
            | EvalPrint Environment
            | ExceptionHandler ExceptionCodeType Code Environment
            | EvalUnaryOp UnaryOpType Environment
            | HoleApp Code Environment
            | AppHole Code
            | Global Environment
            | EvalConsume Environment
            | HolePair Code Environment 
            | PairHole Code Environment
            deriving (Show)

data ListContents = Empty | Next Code ListContents deriving (Eq, Show)

type Kontinuation = [Frame]


type State = (Code, Environment, Store, Kontinuation, Buffer)

collectEnvs :: Kontinuation -> [Environment]
collectEnvs ((Branch p q e):kont) = e:(collectEnvs kont) ++ (unwrapEnvFromCode p)++(unwrapEnvFromCode q)
collectEnvs ((Then p e):kont) = e:(collectEnvs kont) ++ (unwrapEnvFromCode p)
collectEnvs ((EvalRight _ p e):kont) = e:(collectEnvs kont) ++ (unwrapEnvFromCode p)
collectEnvs ((EvalOp _ p e):kont) = e:(collectEnvs kont) ++ (unwrapEnvFromCode p)
collectEnvs ((Assign _ e):kont) = e:(collectEnvs kont)
collectEnvs ((EvalPrint e):kont) = e:(collectEnvs kont)
collectEnvs ((ExceptionHandler _ p e):kont) = e:(collectEnvs kont) ++ (unwrapEnvFromCode p)
collectEnvs ((EvalUnaryOp _ e):kont) = e:(collectEnvs kont)
collectEnvs ((HoleApp p e ):kont) = e:(collectEnvs kont) ++ (unwrapEnvFromCode p)
collectEnvs ((AppHole p):kont) = (unwrapEnvFromCode p)++(collectEnvs kont)
collectEnvs ((Global e):kont) = e:(collectEnvs kont)
collectEnvs ((EvalConsume e):kont) = e:(collectEnvs kont)
collectEnvs ((HolePair p e):kont) = e:(collectEnvs kont) ++ (unwrapEnvFromCode p)
collectEnvs ((PairHole p e):kont) = e:(collectEnvs kont) ++ (unwrapEnvFromCode p)

collectEnvs [] = []

getClosureEnvironment :: Code -> Environment
getClosureEnvironment (Closure _ _ env) = env
getClosureEnvironment _ = Map.empty

getAllClosureEnvs :: Store -> [Environment]
getAllClosureEnvs store = map getClosureEnvironment (Map.elems store) 

envToRef :: [Environment] -> [Int]
envToRef envs = (foldl (union) [] $ map (Map.elems) envs)

usedReferences :: Kontinuation -> Store -> [Int]    
usedReferences kontinuation store = envToRef (collectEnvs kontinuation `union` getAllClosureEnvs store)

unwrapEnvFromCode :: Code -> [Environment]
unwrapEnvFromCode (Closure _ c e) = e:(unwrapEnvFromCode c)
unwrapEnvFromCode (Statement p q) = (unwrapEnvFromCode p) ++ (unwrapEnvFromCode q)
unwrapEnvFromCode (While p q) = (unwrapEnvFromCode p) ++ (unwrapEnvFromCode q)
unwrapEnvFromCode (If p q r) = (unwrapEnvFromCode p) ++ (unwrapEnvFromCode q) ++ (unwrapEnvFromCode r)
unwrapEnvFromCode (Assignment _ p) = (unwrapEnvFromCode p) 
unwrapEnvFromCode (Consume p ) = (unwrapEnvFromCode p) 
unwrapEnvFromCode (Print p) = (unwrapEnvFromCode p) 
unwrapEnvFromCode (TryCatch _ p q) = (unwrapEnvFromCode p) ++ (unwrapEnvFromCode q)
unwrapEnvFromCode (BinOp _ p q) = (unwrapEnvFromCode p) ++ (unwrapEnvFromCode q)
unwrapEnvFromCode (UnaryOp _ p)= (unwrapEnvFromCode p)
unwrapEnvFromCode (Lam _ p) = (unwrapEnvFromCode p)
unwrapEnvFromCode _ = []

garbageCollect :: Environment -> Store -> Kontinuation -> Store
garbageCollect env store kont = Map.filterWithKey (\k _ -> elem k used) store where
    used = (usedReferences kont store) `union` Map.elems env


-- If it is terminal value of the language - return true
isValue :: Code -> Bool
isValue (Void) = True
isValue (Number _) = True
isValue (Boolean _) = True
isValue (Character _) = True
isValue (Location _) = True
isValue (Closure _ _ _) = True
isValue (Unit) = True
isValue (List c) = isEvaluatedList c
isValue (Pair p q) = (isValue p) && (isValue q)
isValue _ = False

isEvaluatedList :: ListContents -> Bool
isEvaluatedList Empty = True
isEvaluatedList (Next val cont) = (isValue val) && (isEvaluatedList cont)

inject :: Code -> State
inject code = (code, Map.empty, Map.empty, [], [])

step :: State -> IO (State)

-- Define new varaible by allocating location for it, adding definition to environemnt and setting store to null
step ((Statement (Definition name) e2), env, store, kontinuation, buffer) = return (e2, newEnv, newStore, kontinuation,buffer)
    where
        newLocation = (freshLocation store)
        newEnv = Map.insert name newLocation env
        newStore = Map.insert newLocation (Null) store

-- If executing a statement e1;e2 - save the environment and e2 on the stack and execute e1
step ((Statement e1 e2), env, store, kontinuation, buffer) = return (e1, env, store, (Then e2 env):kontinuation, buffer)

-- If e1 has terminated, then restore environment and execute e2
step s@(v, env1, store, (Then e2 env2):kontinuation, buffer)
    | isValue v = return (e2, env2, (garbageCollect env2 store ((Then e2 env2):kontinuation)), kontinuation, buffer)

-- When executing If statement - save the environment and both branches in the continuation and evaluate the condition first
step ((If cond lhs rhs), env, store, kontinuation, buffer) = return (cond, env, store, (Branch lhs rhs env):kontinuation, buffer)

-- If condition evaluated to true, perform jumping to the right branchVoid
step (v, env1, store, (Branch lhs rhs env2):kontinuation, buffer)
    | isValue v = case v of
        (Boolean True) -> return (lhs, env2, store, kontinuation, buffer)
        (Boolean False) -> return (rhs, env2, store, kontinuation, buffer)
        _ -> errorWithoutStackTrace "Not a boolean"

-- Desugars while expression into if statement
step (whileExp@(While condition exp), env, store, kontinuation, buffer) = return ((If condition (Statement exp whileExp) (Void)), env, store, kontinuation, buffer)

-- Lookup location of a reference type
step(Reference variableName, env, store, kontinuation, buffer)
    | lookupResult == Nothing = errorWithoutStackTrace ("Dereferencing not existent variable, on variable name: "++ (show variableName)++ " " ++ (show $ head $ kontinuation))
    | otherwise = let (Just v)=lookupResult in
        return (v, env, store, kontinuation, buffer)
    where lookupResult = (Map.lookup variableName env)>>= (\x -> Map.lookup x store)

-- Defining at the end doesnt do anyting
step((Definition _ ), env, store, kontinuation, buffer) = return (Void,env,store,kontinuation, buffer)

-- For mutation - first evaluate expression to value
step (Assignment name expr, env, store, kontinuation, buffer) = return (expr, env, store, (Assign name env):kontinuation, buffer)

-- Mutation of evaluated location
step (val, env2, store, (Assign name env):kontinuation, buffer)
    | lookupResult == Nothing = errorWithoutStackTrace "Trying to mutate not existing variable"
    | isValue val  = let (Just location)=lookupResult in
            return (Void, env, Map.insert location val store, kontinuation, buffer)
        where
            lookupResult = Map.lookup name env

-- When printing something first evaluate it and save the environment
step ((Print e), env, store, kontinuation, buffer) = return (e, env, store, (EvalPrint env):kontinuation, buffer)

-- After evaluating it perform side effect and return Void
step (v, env2, store, (EvalPrint env):kontinuation, buffer) | isValue v =
    do
        putStrLn $ valueToString $ v
        return (Void, env, store, kontinuation, buffer)

-- When seeing the binary operation evaluate left hand side and then save rhs, opeartion type and environment to the stack
step ((BinOp operation lhs rhs), env, store, kontinuation, buffer) = return (lhs, env, store, (EvalRight operation rhs env):kontinuation, buffer)

-- After evaluating the lhs, save result of lhs, restore environment and evaluate rhs
step (v, env2, store, (EvalRight operation rhs env1):kontinuation, buffer)
    | isValue v = return (rhs, env1, store, (EvalOp operation v env1):kontinuation, buffer)

-- After evaluating rhs, perform the operation
step (rhs, env2, store, (EvalOp operation v env1):kontinuation, buffer)
    | isValue rhs = return ((evalBinop operation v rhs),env1,store,kontinuation, buffer)

-- When seing unary operation, try to evaluate it first to terminal value, and save the operation type and environment to the stack
step (UnaryOp opType expr, env, store, kontinuation, buffer) = return (expr, env, store, (EvalUnaryOp opType env):kontinuation, buffer)

-- After evaluating it to the value, perform the unary operation
step (v, env2, store, (EvalUnaryOp opType env):kontinuation, buffer) | isValue v = return (evalUnary opType v, env, store, kontinuation, buffer )

-- When trying to access not initialised address throw NullPointerException
step (Null, env, store, kontinuation, buffer) = return (Exception NullPointerException, env, store, kontinuation, buffer)

-- Initialise buffers with empty values
step (InitStreams numberOfStreams, env, store, kontinuation, buffer) = return (Void, env, store, kontinuation, take numberOfStreams $ repeat [])

-- Evaluate the number of stream which we are going to consume from
step (Consume expr, env, store, kontinuation, buffer) = return (expr, env, store, (EvalConsume env):kontinuation, buffer)

-- Main stream operation function - when something is stored in buffer, fetch it - otherwise just read whole new line and feed it to buffer and recursively feed it to yourself
step (no@(Number num), env, store, (EvalConsume env2):kontinuation, buffer)
    -- checking whether the buffer number is bigger then initial number of buffers (interplay with initBuffer operation)
    | buffer == [] = return (Exception StreamsNotInitialisedException, env, store, kontinuation, buffer)
    | num > length buffer = return (Exception NotExistingStreamConsumptionException, env, store, kontinuation, buffer)
    -- If the buffer for given stream is empty, then try fetching a new line
    | isStreamEmpty num buffer = do
        done<-isEOF
        if done then
            -- Go to halting state
            return (Void, env, store, [], buffer)
        else do
            -- Otherwise fetch a new line
            input<- getLine
            return (Consume no, env2, store, kontinuation, appendToBuffer (processInputLine input) buffer)
    -- If buffer is not empty, then just fetch from it
    | otherwise = return (Number contents, env, store, kontinuation, newBuffer)
        where
            contents = fst consumeResult
            newBuffer = snd consumeResult
            consumeResult = consumeStream num buffer

-- Throwing an exception
step (Throw exType, env, store, kontinuation, buffer) = return (Exception exType, env, store, kontinuation, buffer)

-- Reached top of the stack - no exception handler
step (Exception exType, _, _, [], _) = errorWithoutStackTrace ("Unhandled exception : " ++ show exType)

-- Register an exception handler
step ((TryCatch exType try catch),env,store,kontinuation, buffer) = return (try, env, store, (ExceptionHandler exType catch env):kontinuation, buffer)

-- Finished evaluation inside of an exception handler - no errorWithoutStackTrace
step (v , env2, store, (ExceptionHandler exType catch env):kontinuation, buffer) | isValue v =  return (Void, env, store, kontinuation, buffer)

-- There is an exception, and the handler is correct
step (Exception exType, env2, store, (ExceptionHandler handlerExType catch env):kontinuation, buffer) | exType == handlerExType = return (catch, env, store, kontinuation, buffer)

-- There is an exception, but the correct handler is not present
step (ex@(Exception _), env, store, _:kontinuation, buffer) = return (ex, env, store, kontinuation, buffer)

-- If you see a lambda expression, convert it to closure
step (Lam name expr, env, store, kontinuation, buffer) = return (Closure name expr env, env, store, kontinuation, buffer)

-- Rule for evaluating applications - evaluate lhs first
step ((App e1 e2),env,store, kontinuation, buffer) = return (e1,env, store, (HoleApp e2 env) : kontinuation, buffer)

-- Rule for evaluating applications - lhs is a closure
step (w@(Closure x expr cloEnv),env1,store, (HoleApp e env2):k, buffer ) = return (e, env2, store, (AppHole w) : k, buffer)

-- Perform substitution - and restore the environment in the end - shadow the global bindings with current binding
step (w,env1,store,(AppHole (Closure x e env2) ) : k, buffer ) | isValue w  = return (e, newEnv, newStore, (Global env1):k, buffer)
    where
        location = (freshLocation store)
        newStore = Map.insert location w store
        newEnv = Map.insert x location env2

-- Performed full evaluation, but kontinuation contains old global bindings
step (v, env2, store, (Global env):kontinuation, buffer) = return (v, env, store, kontinuation, buffer)


-- Evaluation rules for pairs
step ((Pair e1 e2),env, store, kontinuation, buffer) = return (e1,env,store, (HolePair e2 env):kontinuation,buffer)

step (v,env1,store, (HolePair e env2):kontinuation, buffer) | isValue v = return (e,env2,store, (PairHole v env1) : kontinuation, buffer)

step (w,env,store, (PairHole v env2):kontinuation, buffer) | isValue w = return ( (Pair v w),env2,store,kontinuation,buffer)


-- For terminal states, evaluated to value, no continuation, just return itself
step state@(v, _, _, [], _) | isValue v = return state

step (c, _,_,_,_) = errorWithoutStackTrace ("Error while evaluation: " ++ show c)


-- Core function for evaluating binary operations
evalBinop :: OpType -> Code -> Code -> Code
evalBinop Add (Number m) (Number n) = (Number (n+m))
evalBinop Multiply (Number m) (Number n) = (Number (m*n))
evalBinop Subtract (Number m) (Number n) = (Number (m-n))
evalBinop Divide (Number m) (Number 0) = (Exception DivideByZeroException)
evalBinop Divide (Number m) (Number n) = (Number (div m n))
evalBinop Modulo (Number m) (Number n) = (Number (mod m n))
evalBinop LessThan (Number m) (Number n) = (Boolean (m<n))
evalBinop LessOrEqual (Number m) (Number n) = (Boolean (m<=n))
evalBinop Equal (Number m) (Number n) = (Boolean (m==n))
evalBinop Equal (Boolean m) (Boolean n) = (Boolean (m==n))
evalBinop Equal (Character m) (Character n) = (Boolean (m==n))
evalBinop Equal (Unit) (Unit) = (Boolean True)
evalBinop Equal (List a) (List b) = Boolean (compareLists a b)
evalBinop Equal (Pair a b) (Pair c d) = evalBinop LogicalAnd (evalBinop Equal a c) (evalBinop Equal b d)
evalBinop Equal (Void) (Void) = (Boolean True)
evalBinop NotEqual (Number m) (Number n) = (Boolean (m/=n))
evalBinop NotEqual (Boolean m) (Boolean n) = (Boolean (m/=n))
evalBinop NotEqual (Character m) (Character n) = (Boolean (m/=n))
evalBinop NotEqual (Unit) (Unit) = (Boolean False)
evalBinop NotEqual (List a) (List b) = Boolean (not (compareLists a b))
evalBinop NotEqual lhs@(Pair a b) rhs@(Pair c d) = evalUnary LogicalNot (evalBinop Equal lhs rhs)
evalBinop NotEqual (Void) (Void) = (Boolean False)
evalBinop GreaterOrEqual (Number m) (Number n) = (Boolean (m>=n))
evalBinop GreaterThan (Number m) (Number n) = (Boolean (m>n))
evalBinop LogicalAnd (Boolean m) (Boolean n) = (Boolean (m && n))
evalBinop LogicalOr (Boolean m) (Boolean n) = (Boolean (m || n))
evalBinop LogicalXor (Boolean m) (Boolean n) = (Boolean (xor m n))
evalBinop ListCons (v) (List contents) | isValue v = List (Next v contents)
evalBinop a b c = errorWithoutStackTrace ("not valid operation: " ++ (show a) ++ " called with arguments: " ++ (show b) ++ " and " ++ (show c))

compareLists :: ListContents -> ListContents -> Bool
compareLists Empty Empty = True
compareLists Empty (Next _ _) = False
compareLists (Next _ _) Empty = False
compareLists (Next v1 n1) (Next v2 n2) = case evalBinop Equal v1 v2 of
    Boolean True -> (compareLists n1 n2)
    otherwise -> False

evalUnary :: UnaryOpType -> Code -> Code
evalUnary LogicalNot (Boolean m) = (Boolean (not m))
evalUnary Negate (Number m) = (Number (-m))
evalUnary Head (List (Next val _)) = val
evalUnary Head (List Empty) = (Exception ListEmptyException)
evalUnary Tail (List (Next h tail)) = List tail
evalUnary Tail (List Empty) = (Exception ListEmptyException)
evalUnary ListIsEmpty (List Empty) = (Boolean True)
evalUnary ListIsEmpty (List _) = (Boolean False)
evalUnary FstOp (Pair p _) = p
evalUnary SndOp (Pair _ q) = q


evalUnary _ _ = errorWithoutStackTrace "not valid"

-- Allows printing values to output stream
valueToString :: Code -> String
valueToString (Number n) = show n
valueToString (Boolean True) = "True"
valueToString (Boolean False) = "False"
valueToString (List (Empty)) = ""
valueToString (Character c) = [c]
valueToString (List (Next (Character c) cs)) = ([c])++(valueToString (List cs))
valueToString (List contents ) = "[" ++ (foldr (\a -> \b -> if b =="" then (valueToString a) else ((valueToString a) ++ "," ++ b))  "" (convertList contents)) ++ "]"
valueToString (Closure _ _ _) = "(closure)"
valueToString (Unit) = "()"
valueToString (Pair p q) = "("++(valueToString p)++","++(valueToString q)++")"
valueToString _ = errorWithoutStackTrace "inpossible to print"

convertList :: ListContents -> [Code]
convertList (Empty) = []
convertList (Next a b) = a:convertList b

-- Is it a terminals state
isTerminal :: State -> Bool
isTerminal (v, _, _, [], _) | isValue v = True
isTerminal _ = False

-- If terminal state, then stop and return it, otherwise perform small step evaluation and recursively call itself
evalLoop :: State -> IO (State)
evalLoop s = if isTerminal s then (return s) else (step s)>>=evalLoop

-- Takes a program, performs injection to initial state and runs it inside of IO Monad
runProgram :: Code -> IO ()
runProgram code = do
    evalLoop $ inject $ code
    return ()

-- Finds a new address in store part of CESK
freshLocation :: (Num a, Enum a, Ord a) => Map.Map a b -> a
freshLocation map =  head ([x| x<-[0..], not (Map.member x map)])

-- Just splits the input line by spaces
processInputLine ::  String -> [Int]
processInputLine = \x ->  map (read) (splitOn ' ' x) :: [Int]

-- Function for splliting String into list of Dtrings - Taken from Julian's Rathke solution of lab1 for PLC
splitOn :: Char -> String -> [String]
splitOn c [] = []
splitOn c ls = (takeWhile (/=c) ls) : splitOn' c (dropWhile (/=c) ls)
 where splitOn' c [] = []
       splitOn' c (x:[]) | x==c = [[]]
       splitOn' c (x:xs) | x==c = splitOn c xs
                         | otherwise = []

-- Takes a list of Integers and a buffer, and creats new buffer with those elements at the end of the buffer
appendToBuffer :: [Int] -> [[Int]] -> [[Int]]
appendToBuffer [] xss = xss
appendToBuffer (x:xs) [] = [x] : (appendToBuffer xs [])
appendToBuffer (x:xs) (ys:yss) = (ys++[x]):(appendToBuffer xs yss)

-- Check whether given stream in the buffer is empty and needs fetching a new line
isStreamEmpty :: Int -> [[Int]] -> Bool
isStreamEmpty 0 (xs:xss) |  xs == [] = True
                         | otherwise = False
isStreamEmpty n (xs:xss) = isStreamEmpty (n-1) (xss)
isStreamEmpty _ _ = True

-- Helper function for consume stream
appendAtFront :: (Int,[[Int]]) -> [Int] -> (Int,[[Int]])
appendAtFront (num, xss) xs = (num, xs:xss)

-- Takes a stream number and a buffer and gives element of the stream and new buffer
consumeStream :: Int -> [[Int]] -> (Int,[[Int]])
consumeStream 0 (xs:xss) = (head xs, (tail xs):xss)
consumeStream n (xs:xss) = appendAtFront (consumeStream (n-1) (xss)) xs
consumeStream _ _ = errorWithoutStackTrace "cannot consume from empty stream"


convertString :: String -> ListContents
convertString "" = Empty
convertString (a:as) = (Next (Character a) (convertString as))

convertException :: ExceptionType -> ExceptionCodeType
convertException (NullPointer) = NullPointerException
convertException (StreamsNotIntialised) = StreamsNotInitialisedException
convertException NotExistingStreamConsumption = NotExistingStreamConsumptionException
convertException DivideByZero = DivideByZeroException
convertException Trap = TrapException
convertException ListEmpty = ListEmptyException


-- Converts type checked output from parser to bytecode
convert :: Stmt -> Code
convert (Stmt a as) = (Statement (convert a) (convert as))
convert (NumVal n) = (Number n)
convert (StringVal n) = (List (convertString n))
convert (UnitVal) = (Unit)
convert (EmptyListVal) = (List Empty)
convert (BoolVal b) = (Boolean b)
convert (Variable v) = (Reference v)
-- this one needs fixing
convert (Streams (NumVal s)) = (InitStreams s)
convert (Streams _) = errorWithoutStackTrace "Streams must be initialised with a number"
convert (PrintOp s) = (Print (convert s))
convert (Declaration _ name) = (Definition name)
convert (AssignmentStmt name val) = (Assignment name (convert val))
convert (WhileStmt cond body) = (While (convert cond) (convert body))
convert (IfStmtElse cond a b) = (If (convert cond) (convert a) (convert b))
convert (IfStmt cond a) = (If (convert cond) (convert a) (Void))
convert (ConsumeStream (n)) = (Consume (convert n))
convert (TryCatchStmt body ex handler) = (TryCatch  (convertException ex) (convert body) (convert handler))
convert (ThrowStmt ex) = (Throw (convertException ex))
convert (AddOp lhs rhs) = (BinOp Add (convert lhs) (convert rhs))
convert (LessThanOp lhs rhs) = (BinOp LessThan (convert lhs) (convert rhs))
convert (LessThanEqOp lhs rhs) = (BinOp LessOrEqual (convert lhs) (convert rhs))
convert (GreaterThanOp lhs rhs) = (BinOp GreaterThan (convert lhs) (convert rhs))
convert (GreaterThanEqOp lhs rhs) = (BinOp GreaterOrEqual (convert lhs) (convert rhs))
convert (ConsOp lhs rhs) = (BinOp ListCons (convert lhs) (convert rhs))
convert (SubtractOp lhs rhs) = (BinOp Subtract (convert lhs) (convert rhs))
convert (ModuloOp lhs rhs) = (BinOp Modulo (convert lhs) (convert rhs))
convert (DivideOp lhs rhs) = (BinOp Divide (convert lhs) (convert rhs))
convert (MultiplyOp lhs rhs) = (BinOp Multiply (convert lhs) (convert rhs))
convert (EqualOp lhs rhs) = (BinOp Equal (convert lhs) (convert rhs))
convert (NotEqualOp lhs rhs) = (BinOp NotEqual (convert lhs) (convert rhs))
convert (OrOp lhs rhs) = (BinOp LogicalOr (convert lhs) (convert rhs))
convert (AndOp lhs rhs) = (BinOp LogicalAnd (convert lhs) (convert rhs))
convert (NegateOp v) = (UnaryOp Negate (convert v))
convert (NotOp v) = (UnaryOp LogicalNot (convert v))
convert (HeadOp v) = (UnaryOp Head (convert v))
convert (TailOp v) = (UnaryOp Tail (convert v))
convert (IsEmptyOp v) = (UnaryOp ListIsEmpty (convert v))
convert (LamExpr _ var expr) = (Lam var (convert expr))
convert (Application lhs rhs) = (App (convert lhs) (convert rhs))
convert (ReturnOp v) = (convert v)
convert (PairVal p q) = (Pair (convert p) (convert q))
convert (First p) = (UnaryOp FstOp (convert p))
convert (Second q) = (UnaryOp SndOp (convert q))
convert (CharVal c) = (Character c)