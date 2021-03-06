{
module MCParser where
import MCLexer
import SyntaxCheck
}
%name parse
%tokentype { Token }
%error { parseError }


%token
      if              { MkToken _ TokenIf}
      while           { MkToken _ TokenWhile}
      else            { MkToken _ TokenElse}
      '='             { MkToken _ TokenEq}
      '+'             { MkToken _ TokenAdd}
      '{'             { MkToken _ TokenLCurly}
      '}'             { MkToken _ TokenRCurly}
      '['             { MkToken _ TokenLSquare}
      ']'             { MkToken _ TokenRSquare}
      '('             { MkToken _ TokenLParen}
      ')'             { MkToken _ TokenRParen}
      ':'             { MkToken _ TokenColon}
      ';'             { MkToken _ TokenSemiColon}
      '<'             { MkToken _ TokenLessThan}
      '>'             { MkToken _ TokenGreaterThan}
      '<='            { MkToken _ TokenLessThanEq}
      '>='            { MkToken _ TokenGreaterThanEq}
      '=='            { MkToken _ TokenLogicalEq}
      '!='            { MkToken _ TokenNotEq }
      '!'             { MkToken _ TokenLogicalNot}
      '&&'            { MkToken _ TokenLogicalAnd}
      '||'            { MkToken _ TokenLogicalOr }
      '/'             { MkToken _ TokenDivide}
      '*'             { MkToken _ TokenMultiply}
      '-'             { MkToken _ TokenSubtract }
      '%'             { MkToken _ TokenModulo}
      ','             { MkToken _ TokenComma }
      catch           { MkToken _ TokenCatch}
      try             { MkToken _ TokenTry}
      throw           { MkToken _ TokenThrow}
      number          { MkToken _ (TokenNum $$)}
      string          { MkToken _ (TokenString $$)}
      intT            { MkToken _ TokenTInt}
      char            { MkToken _ TokenTChar}
      bool            { MkToken _ (TokenBool $$)}
      boolT           { MkToken _ TokenTBool}
      void            { MkToken _ TokenVoid}
      var             { MkToken _ (TokenVar $$)}
      print           { MkToken _ TokenPrint}
      head            { MkToken _ TokenHead}
      tail            { MkToken _ TokenTail}
      isEmpty         { MkToken _ TokenIsEmpty}
      cons            { MkToken _ TokenCons}
      consume         { MkToken _ TokenConsume}
      streams         { MkToken _ TokenInitStreams}
      lambda          { MkToken _ TokenLambda}
      '->'            { MkToken _ TokenArrow}
      unit            { MkToken _ TokenUnit}
      return          { MkToken _ TokenReturn}
      fst             { MkToken _ TokenFst}
      snd             { MkToken _ TokenSnd}
      include         { MkToken _ TokenInclude}  
      NullPointerException                  { MkToken _ TokenNPE}
      StreamsNotInitialisedException        { MkToken _ TokenSNIE}
      NotExistingStreamConsumptionException { MkToken _ TokenNESCE}
      DivideByZeroException                 { MkToken _ TokenDBZE}
      TrapException                         { MkToken _ TokenTE}
      ListEmptyException                    { MkToken _ TokenLEE}
      character                             { MkToken _ (TokenChar $$)}


%nonassoc '<' '>' '>=' '<=' '==' '!='
%left '+' '-' '&&' '||' cons
%right '*' '/' '%' '->'
%left UNARY
%%


Stmt : Expression ';' Stmt         {Stmt $1 $3}
          | Expression ';'                   {$1}
          | Selection_Stmt Stmt    {Stmt $1 $2}
          | Iteration_Stmt Stmt    {Stmt $1 $2}
          | Function_Stmt Stmt     {Stmt $1 $2}
          | Selection_Stmt              {$1}
          | Iteration_Stmt              {$1}
          | Function_Stmt               {$1}

Selection_Stmt:      if '(' Expression ')' Compound_Stmt else Compound_Stmt  {IfStmtElse $3 $5 $7}
                   | if '(' Expression ')' Compound_Stmt                          {IfStmt $3 $5}
                   | try Compound_Stmt catch '(' Exception ')' Compound_Stmt {TryCatchStmt $2 $5 $7}

Iteration_Stmt: while '(' Expression ')' Compound_Stmt {WhileStmt $3 $5}

Function_Stmt : Type var '(' FuncParams ')' Compound_Stmt {FuncDef $1 $2 $4 $6}
              | Type var unit Compound_Stmt               {FuncDef $1 $2 (Declaration UnitT "()") $4}

Compound_Stmt: '{' Stmt '}' {$2}

Expression : Operation                      {$1}
           | var '=' Expression             {AssignmentStmt $1 $3}
           | var '=' unit                   {AssignmentStmt $1 UnitVal}
           | Type var                       {Declaration $1 $2}
           | Type var '=' Expression        {Stmt (Declaration $1 $2) (AssignmentStmt $2 $4)}
           | Type var '=' unit              {Stmt (Declaration $1 $2) (AssignmentStmt $2 UnitVal)}
           | print Expression               {PrintOp $2}
           | consume Expression             {ConsumeStream $2}
           | streams Expression             {Streams $2}
           | fst Expression                 {First $2}
           | snd Expression                 {Second $2}
           | return Expression              {ReturnOp $2}
           | return unit                    {ReturnOp UnitVal}
           | throw Exception                {ThrowStmt $2}
           | lambda '(' Type var ')' '->' Compound_Stmt  {LamExpr $3 $4 $7}
           | lambda unit '->' Compound_Stmt {LamExpr UnitT "()" $4}
           | include string                  {Include $2}

FuncParams : Type var ',' FuncParams {Stmt (Declaration $1 $2) $4}
           | unit ',' FuncParams     {Stmt (Declaration UnitT "()") $3}
           | Type var                {Declaration $1 $2}
           | unit                    {Declaration UnitT "()"}

Operation      : Operation '+'  Operation     {AddOp $1 $3}
               | Operation '-'  Operation     {SubtractOp $1 $3}
               | Operation '<'  Operation     {LessThanOp $1 $3}
               | Operation '<=' Operation     {LessThanEqOp $1 $3}
               | Operation '>'  Operation     {GreaterThanOp $1 $3}
               | Operation '>=' Operation     {GreaterThanEqOp $1 $3}
               | Operation '*'  Operation     {MultiplyOp $1 $3}
               | Operation '%'  Operation     {ModuloOp $1 $3}
               | Operation '/'  Operation     {DivideOp $1 $3}
               | Operation '==' Operation     {EqualOp $1 $3}
               | Operation '!=' Operation     {NotEqualOp $1 $3}
               | Operation '||' Operation     {OrOp $1 $3}
               | Operation '&&' Operation     {AndOp $1 $3}
               | Operation cons Operation     {ConsOp $1 $3}
               | '-' Operation  %prec UNARY   {NegateOp $2}
               | '!' Operation  %prec UNARY   {NotOp $2}
               | tail Operation %prec UNARY   {TailOp $2}
               | head Operation %prec UNARY   {HeadOp $2}
               | isEmpty Operation %prec UNARY{IsEmptyOp $2}
               | Exp1                         {$1}

Exp1           : Exp1 Exp2                    {Application $1 $2}
               | Exp1 unit                    {Application $1 UnitVal}
               | Exp2                         {$1}


Exp2 : '(' Expression ')'                                                  {$2}
     | string                                                             {StringVal $1}
     | var                                                                {Variable $1}
     | bool                                                               {BoolVal $1}
     | number                                                             {NumVal $1}
     | character                                                          {CharVal $1}
     | '(' Expression ',' Expression ')'                                  {PairVal $2 $4}
     | '[' ']'                                                            {EmptyListVal}

Exception : NullPointerException                  {NullPointer}
          | StreamsNotInitialisedException        {StreamsNotIntialised}
          | NotExistingStreamConsumptionException {NotExistingStreamConsumption}
          | DivideByZeroException                 {DivideByZero}
          | TrapException                         {Trap}
          | ListEmptyException                    {ListEmpty}

Type : boolT             {BoolT}
     | intT              {IntT}
     | void              {VoidT}
     | char              {CharT}
     | unit              {UnitT}
     | '[' Type ']'      {ListT $2}
     | Type '->' Type    {ArrowT $1 $3}
     | '(' Type ')'      {$2}
     | '(' Type ',' Type ')' {PairT $2 $4}

{


data Stmt =      Include String
               | Stmt Stmt Stmt
               | IfStmtElse Stmt Stmt Stmt
               | IfStmt Stmt Stmt
               | WhileStmt Stmt Stmt
               | AssignmentStmt String Stmt
               | FuncDef Type String Stmt Stmt
               | Declaration Type String
               | PrintOp Stmt
               | BoolVal Bool
               | Variable String
               | NumVal Int
               | Streams Stmt
               | StringVal String
               | ConsumeStream Stmt
               | TryCatchStmt Stmt ExceptionType Stmt
               | ThrowStmt ExceptionType
               | AddOp Stmt Stmt
               | LessThanOp Stmt Stmt
               | LessThanEqOp Stmt Stmt
               | GreaterThanOp Stmt Stmt
               | GreaterThanEqOp Stmt Stmt
               | SubtractOp Stmt Stmt
               | MultiplyOp Stmt Stmt
               | ModuloOp Stmt Stmt
               | DivideOp Stmt Stmt
               | EqualOp Stmt Stmt
               | NotEqualOp Stmt Stmt
               | OrOp Stmt Stmt
               | AndOp Stmt Stmt
               | NegateOp Stmt
               | NotOp Stmt
               | LamExpr Type String Stmt
               | Application Stmt Stmt
               | UnitVal
               | HeadOp Stmt
               | TailOp Stmt
               | IsEmptyOp Stmt
               | ConsOp Stmt Stmt
               | EmptyListVal
               | ReturnOp Stmt
               | PairVal Stmt Stmt
               | First Stmt
               | Second Stmt
               | CharVal Char
               deriving (Show)

data ExceptionType = NullPointer
               | StreamsNotIntialised
               | NotExistingStreamConsumption
               | DivideByZero
               | Trap
               | ListEmpty
               deriving (Show)

data Type     = IntT
              | BoolT
              | VoidT
              | StmtT
              | UnitT
              | StringT
              | ListT Type
              | EmptyListT
              | ArrowT Type Type
              | CharT
              | PairT Type Type
              deriving (Show, Eq)

parseError :: [Token] -> a
parseError input = errorWithoutStackTrace (parseErrorMessage (line token) (column token) ++ "\n" ++ guessCauseOfError tokenClasses)
  where
    token = head input
    tokenClasses = map extractTokenClass input

parseErrorMessage :: Int -> Int -> String
parseErrorMessage li col =  "Error parsing around line: " ++ (show li) ++ " column: " ++ (show col)

guessCauseOfError :: [TokenClass] -> String
guessCauseOfError (TokenLCurly : tks) = "You have probably forgotten ')' or '->'"
guessCauseOfError _ = "You might have forgotten ';' in the previous statement"

modParse :: [Token] -> Stmt
modParse tks = modParse' parsedTks
     where
          parsedTks = parse tks

modParse' :: Stmt -> Stmt
modParse' (Stmt (Stmt decl@(Declaration varType varName)assign@(AssignmentStmt name val)) rest ) = 
     (Stmt (decl) (Stmt (assign) (modParse' rest)))
modParse' (Stmt (FuncDef rtype fname boundVars funBody) rest)= 
      (Stmt (Declaration (genFunType boundVars rtype ) fname ) (Stmt (AssignmentStmt fname (genLamFunc boundVars funBody))
     (modParse' rest)))
modParse' (FuncDef rtype fname boundVars funBody) = (Stmt (Declaration (genFunType boundVars rtype ) fname ) ((AssignmentStmt fname (genLamFunc boundVars funBody))))
modParse' (Stmt e1 e2) = (Stmt (modParse' e1) (modParse' e2))
modParse' x = x

genFunType :: Stmt -> Type -> Type
genFunType (Stmt (Declaration varType _) otherVars) returnType =
      (ArrowT varType (genFunType otherVars returnType))
genFunType (Declaration varType _) returnType = ArrowT varType returnType

genLamFunc :: Stmt -> Stmt -> Stmt
genLamFunc (Stmt (Declaration varType varName) otherVars) funBody =
     (LamExpr varType varName (genLamFunc otherVars funBody))
genLamFunc (Declaration varType varName) funBody = (LamExpr varType varName funBody)
}
