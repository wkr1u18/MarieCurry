{
module MCLexer where
}

%wrapper "posn"
$digit = 0-9
-- digits
$alpha = [a-zA-Z]
-- alphabetic characters

tokens :-
  $white+       ;
  "--".*        ;
  $digit+ {\p s -> MkToken p (TokenNum (read s)) }
  true    {\p s -> MkToken p (TokenBool True)}
  false   {\p s -> MkToken p (TokenBool False)}
  int     {\p s -> MkToken p TokenTInt }
  bool    {\p s -> MkToken p TokenTBool }
  void    {\p s -> MkToken p TokenVoid }
  null    {\p s -> MkToken p TokenNull }
  if      {\p s -> MkToken p TokenIf }
  else    {\p s -> MkToken p TokenElse }
  while   {\p s -> MkToken p TokenWhile }
  print   {\p s -> MkToken p TokenPrint }
  stream  {\p s -> MkToken p TokenInitStream }
  consume {\p s -> MkToken p TokenConsume }
  try     {\p s -> MkToken p TokenTry}
  catch   {\p s -> MkToken p TokenCatch}
  throw   {\p s -> MkToken p TokenThrow }
  "="     {\p s -> MkToken p TokenEq }
  "<"     {\p s -> MkToken p TokenLessThan }
  "<="    {\p s -> MkToken p TokenLessThanEq }
  ">"     {\p s -> MkToken p TokenGreaterThan }
  ">="    {\p s -> MkToken p TokenGreaterThanEq}
  "=="    {\p s -> MkToken p TokenLogicalEq}
  "!="    {\p s -> MkToken p TokenNotEq }
  "!"     {\p s -> MkToken p TokenLogicalNot}
  "&&"    {\p s -> MkToken p TokenLogicalAnd}
  "||"    {\p s -> MkToken p TokenLogicalOr }
  "/"     {\p s -> MkToken p TokenDivide}
  "+"     {\p s -> MkToken p TokenAdd }
  "*"     {\p s -> MkToken p TokenMultiply}
  "-"     {\p s -> MkToken p TokenSubtract }
  "%"     {\p s -> MkToken p TokenModulo}
  ";"     {\p s -> MkToken p TokenSemiColon }
  ":"     {\p s -> MkToken p TokenColon }
  "("     {\p s -> MkToken p TokenLParen }
  ")"     {\p s -> MkToken p TokenRParen }
  "{"     {\p s -> MkToken p TokenLCurly }
  "}"     {\p s -> MkToken p TokenRCurly}
  NullPointerException                    {\p s -> MkToken p TokenNPE}
  StreamsNotInitialisedException          {\p s -> MkToken p TokenSNIE}
  NotExistingStreamConsumptionException   {\p s -> MkToken p TokenNESCE}
  DivideByZeroException                   {\p s -> MkToken p TokenDBZE}
  TrapException                           {\p s -> MkToken p TokenTE}
  $alpha [$alpha $digit \_ \’]*           {\p s -> MkToken p (TokenVar s)}
{

-- The token type:
data Token = MkToken AlexPosn TokenClass
    deriving (Show,Eq)

data TokenClass =
  TokenNum          Int       |
  TokenBool         Bool      |
  TokenVar          String    |
  TokenIf                     |
  TokenElse                   |
  TokenWhile                  |
  TokenLessThan               |
  TokenAdd                    |
  TokenColon                  |
  TokenSemiColon              |
  TokenLParen                 |
  TokenRParen                 |
  TokenLCurly                 |
  TokenRCurly                 |
  TokenEq                     |
  TokenTInt                   |
  TokenTBool                  |
  TokenPrint                  |
  TokenConsume                |
  TokenInitStream             |
  TokenNull                   |
  TokenVoid                   |
  TokenModulo                 |
  TokenSubtract               |
  TokenDivide                 |
  TokenMultiply               |
  TokenLessThanEq             |
  TokenGreaterThan            |
  TokenGreaterThanEq          |
  TokenLogicalEq              |
  TokenNotEq                  |
  TokenLogicalNot             |
  TokenLogicalAnd             |
  TokenLogicalOr              |
  TokenTry                    |
  TokenCatch                  |
  TokenThrow                  |
  TokenNPE                    |
  TokenSNIE                   |
  TokenNESCE                  |
  TokenDBZE                   |
  TokenTE
    deriving (Show,Eq)


tokenPosn :: Token -> (Int, Int)
tokenPosn (MkToken (AlexPn _ line col) _) = (line, col)
}
