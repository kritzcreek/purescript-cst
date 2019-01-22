{
module Language.PureScript.CST.Parser
  ( parseType
  , parseKind
  -- , parseExpr
  , parseModule
  ) where

import Prelude

import Data.Foldable (foldl')
import Data.Text (Text)
import Language.PureScript.CST.Types
import Language.PureScript.CST.Utils
}

%name parseKind kind
%name parseType type
-- %name parseExpr expr
%name parseModule module
%tokentype { SourceToken }
%errorhandlertype explist
%error { (error . show . (\(a, b) -> (map snd a, b))) }

%token
  '('             { (_, TokLeftParen) }
  ')'             { (_, TokRightParen) }
  '{'             { (_, TokLeftBrace) }
  '}'             { (_, TokRightBrace) }
  '['             { (_, TokLeftSquare) }
  ']'             { (_, TokRightSquare) }
  '\{'            { (_, TokLayoutStart) }
  '\}'            { (_, TokLayoutEnd) }
  '\;'            { (_, TokLayoutSep) }
  '<-'            { (_, TokLeftArrow _) }
  '->'            { (_, TokRightArrow _) }
  '<='            { (_, TokSymbol [] sym) | sym == "<=" || sym == "⇐" }
  '=>'            { (_, TokRightFatArrow _) }
  ':'             { (_, TokSymbol [] ":") }
  '::'            { (_, TokDoubleColon _) }
  '='             { (_, TokEquals) }
  '|'             { (_, TokPipe) }
  '`'             { (_, TokTick) }
  '.'             { (_, TokDot) }
  ','             { (_, TokComma) }
  '_'             { (_, TokUnderscore) }
  '#'             { (_, TokSymbol [] "#") }
  '@'             { (_, TokSymbol [] "@") }
  '..'            { (_, TokSymbol [] "..") }
  'lambda'        { (_, TokSymbol [] "\\") }
  'ado'           { (_, TokLowerName _ "ado") }
  'as'            { (_, TokLowerName [] "as") }
  'case'          { (_, TokLowerName [] "case") }
  'class'         { (_, TokLowerName [] "class") }
  'data'          { (_, TokLowerName [] "data") }
  'derive'        { (_, TokLowerName [] "derive") }
  'do'            { (_, TokLowerName _ "do") }
  'else'          { (_, TokLowerName [] "else") }
  'false'         { (_, TokLowerName [] "false") }
  'forall'        { (_, TokLowerName [] "forall") }
  'forallu'       { (_, TokSymbol [] "∀") }
  'foreign'       { (_, TokLowerName [] "foreign") }
  'import'        { (_, TokLowerName [] "import") }
  'if'            { (_, TokLowerName [] "if") }
  'in'            { (_, TokLowerName [] "in") }
  'infix'         { (_, TokLowerName [] "infix") }
  'infixl'        { (_, TokLowerName [] "infixl") }
  'infixr'        { (_, TokLowerName [] "infixr") }
  'instance'      { (_, TokLowerName [] "instance") }
  'kind'          { (_, TokLowerName [] "kind") }
  'let'           { (_, TokLowerName [] "let") }
  'module'        { (_, TokLowerName [] "module") }
  'newtype'       { (_, TokLowerName [] "newtype") }
  'of'            { (_, TokLowerName [] "of") }
  'then'          { (_, TokLowerName [] "then") }
  'true'          { (_, TokLowerName [] "true") }
  'type'          { (_, TokLowerName [] "type") }
  'where'         { (_, TokLowerName [] "where") }
  IDENT           { (_, TokLowerName [] _) }
  QUAL_IDENT      { (_, TokLowerName _ _) }
  PROPER          { (_, TokUpperName [] _) }
  QUAL_PROPER     { (_, TokUpperName _ _) }
  SYMBOL          { (_, TokSymbol _ _) }
  LIT_HOLE        { (_, TokHole _) }
  LIT_CHAR        { (_, TokChar _ _) }
  LIT_STRING      { (_, TokString _ _) }
  LIT_RAW_STRING  { (_, TokRawString _) }
  LIT_INT         { (_, TokInt _ _) }
  LIT_NUMBER      { (_, TokNumber _ _) }

%%

many(a) :: { [_] }
  : many0(a) { reverse $1 }

many0(a) :: { [_] }
  : a { [$1] }
  | many0(a) a { $2 : $1 }

manySep(a, sep) :: { [_] }
  : manySep0(a, sep) { reverse $1 }

manySep0(a, sep) :: { [_] }
  : a { [$1] }
  | manySep0(a, sep) sep a { $3 : $1 }

manyOrEmpty(a) :: { [_] }
  : {- empty -} { [] }
  | many(a) { $1 }

sep(a, s) :: { Separated _ }
  : sep0(a, s) { separated $1 }

sep0(a, s) :: { [(SourceToken, _)] }
  : a { [(placeholder, $1)] }
  | sep0(a, s) s a { ($2, $3) : $1 }

delim(a, b, c, d) :: { Delimited _ }
  : a d { Wrapped $1 Nothing $2 }
  | a sep(b, c) d { Wrapped $1 (Just $2) $3 }

properIdent :: { Ident }
  : PROPER { toIdent $1 }
  | QUAL_PROPER { toIdent $1 }

proper :: { Ident }
  : PROPER { toIdent $1 }

ident :: { Ident }
  : IDENT { toIdent $1 }
  | QUAL_IDENT { toIdent $1 }

var :: { Ident }
  : IDENT { toVar $1 }

symbol :: { Ident }
  : SYMBOL { toSymbol $1 }

label :: { Ident }
  : IDENT { toLabel $1 }
  | LIT_STRING { toLabel $1 }
  | LIT_RAW_STRING { toLabel $1 }

hole :: { Ident }
  : LIT_HOLE { toIdent $1 }

string :: { (SourceToken, Text) }
  : LIT_STRING { toString $1 }
  | LIT_RAW_STRING { toString $1 }

char :: { (SourceToken, Char) }
  : LIT_CHAR { toChar $1 }

number :: { (SourceToken, Either Integer Double) }
  : LIT_INT { toNumber $1 }
  | LIT_NUMBER { toNumber $1 }

int :: { (SourceToken, Integer) }
  : LIT_INT { toInt $1 }

boolean :: { (SourceToken, Bool) }
  : 'true' { toBoolean $1 }
  | 'false' { toBoolean $1 }

kind :: { Kind () }
  : kind0 { $1 }
  | kind0 '->' kind { KindArr () $1 $2 $3 }

kind0 :: { Kind () }
  : properIdent { KindName () $1 }
  | '#' kind0 { KindRow () $1 $2 }
  | '(' kind ')' { KindParens () (Wrapped $1 $2 $3) }

type :: { Type () }
  : type0 { $1 }
  | forall many(typeVarBinding) '.' type { TypeForall () $1 $2 $3 $4 }

type0 :: { Type () }
  : type1 { $1 }
  | type1 '->' type { TypeArr () $1 $2 $3 }
  | type1 '=>' type { TypeConstrained () $1 $2 $3 }

type1 :: { Type () }
  : type2 { $1 }
  | type1 symbol type2 { TypeOp () $1 $2 $3 }

type2 :: { Type () }
  : typeAtom { $1 }
  | typeAtom typeAtom { TypeApp () $1 $2 }

typeAtom :: { Type ()}
  : '_' { TypeWildcard () $1 }
  | IDENT { TypeVar () (toIdent $1) }
  | PROPER { TypeConstructor () (toIdent $1) }
  | QUAL_PROPER { TypeConstructor () (toIdent $1) }
  | LIT_STRING { uncurry (TypeString ()) (toString $1) }
  | LIT_RAW_STRING { uncurry (TypeString ()) (toString $1) }
  | LIT_HOLE { TypeHole () (toIdent $1) }
  | '{' row '}' { TypeRecord () (Wrapped $1 $2 $3) }
  | '(' row ')' { TypeRow () (Wrapped $1 $2 $3) }
  | '(' type ')' { TypeParens () (Wrapped $1 $2 $3) }
  | '(' typeKindedAtom '::' kind ')' { TypeParens () (Wrapped $1 (TypeKinded () $2 $3 $4) $5) }

typeKindedAtom :: { Type () }
  : '_' { TypeWildcard () $1 }
  | LIT_HOLE { TypeHole () (toIdent $1) }
  | PROPER { TypeConstructor () (toIdent $1) }
  | QUAL_PROPER { TypeConstructor () (toIdent $1) }
  | '{' row '}' { TypeRecord () (Wrapped $1 $2 $3) }
  | '(' row ')' { TypeRow () (Wrapped $1 $2 $3) }
  | '(' type ')' { TypeParens () (Wrapped $1 $2 $3) }
  | '(' typeKindedAtom '::' kind ')' { TypeParens () (Wrapped $1 (TypeKinded () $2 $3 $4) $5) }

row :: { Row () }
  : {- empty -} { Row Nothing Nothing }
  | '|' type { Row Nothing (Just ($1, $2)) }
  | sep(rowLabel, ',') { Row (Just $1) Nothing }
  | sep(rowLabel, ',') '|' type { Row (Just $1) (Just ($2, $3)) }

rowLabel :: { Labeled (Type ()) }
  : label '::' type { Labeled $1 $2 $3 }

typeVarBinding :: { TypeVarBinding () }
  : var { TypeVarName $1 }
  | '(' var '::' kind ')' { TypeVarKinded (Wrapped $1 (Labeled $2 $3 $4) $5) }

forall :: { SourceToken }
  : 'forall' { $1 }
  | 'forallu' { $1 }

exprWhere :: { Expr () }
  : expr { $1 }
  | expr 'where' '\{' manySep(letBinding, '\;') '\}' { ExprWhere () (Where $1 $2 $4) }

expr :: { Expr () }
  : expr0 { $1 }
  | expr0 '::' type { ExprTyped () $1 $2 $3 }

expr0 :: { Expr () }
  : expr1 { $1 }
  | 'if' expr 'then' expr 'else' expr { ExprIf () (IfThenElse $1 $2 $3 $4 $5 $6) }
  | 'let' '\{' manySep(letBinding, '\;') '\}' 'in' expr { ExprLet () (LetIn $1 $3 $5 $6) }
  | 'case' sep(expr, ',') 'of' '\{' manySep(caseBranch, '\;') '\}' { ExprCase () (CaseOf $1 $2 $3 $5) }
  | 'do' '\{' manySep(doStatement, '\;') '\}' { ExprDo () (DoBlock $1 $3) }
  | 'ado' '\{' manySep(doStatement, '\;') '\}' 'in' expr { ExprAdo () (AdoBlock $1 $3 $5 $6) }
  | 'lambda' many(binder) '->' expr { ExprLambda () (Lambda $1 $2 $3 $4) }

expr1 :: { Expr () }
  : exprAtom { $1 }
  | expr1 symbol expr0 { ExprOp () $1 $2 $3}
  | expr1 '`' expr '`' expr0 { ExprInfix () (Infix $1 $2 $3 $4 $5) }
  | expr1 expr0 { ExprApp () $1 $2 }

exprAtom :: { Expr () }
  : '_' { ExprSection () $1 }
  | hole { ExprHole () $1 }
  | ident { ExprIdent () $1 }
  | proper { ExprConstructor () $1 }
  | boolean { uncurry (ExprBoolean ()) $1 }
  | char { uncurry (ExprChar ()) $1 }
  | string { uncurry (ExprString ()) $1 }
  | number { uncurry (ExprNumber ()) $1 }
  | array(expr) { ExprArray () $1 }
  | record(expr) { ExprRecord () $1 }
  | '(' expr ')' { ExprParens () (Wrapped $1 $2 $3) }

array(a) :: { Delimited _ }
  : delim('[', a, ',', ']') { $1 }

record(a) :: { Delimited (RecordLabeled _) }
  : delim('{', recordLabel(a), ',', '}') { $1 }

recordLabel(a) :: { RecordLabeled _ }
  : var { RecordPun $1 }
  | label ':' a { RecordField $1 $2 $3 }

letBinding :: { LetBinding () }
  : var '::' type { LetBindingSignature () (Labeled $1 $2 $3) }
  | var manyOrEmpty(binderAtom) guarded('=') { LetBindingName () (ValueBindingFields $1 $2 $3) }
  | binderLiteral '=' expr { LetBindingPattern () $1 $2 $3 }

binder
  : binder0 { $1 }
  | binder symbol binder0 { BinderOp () $1 $2 $3 } -- TODO conflict with @

binder0
  : binderAtom { $1 }
  | properIdent many(binderAtom) { BinderConstructor () $1 $2 }

binderAtom
  : binderLiteral { $1 }
  | var { BinderVar () $1 }

binderLiteral
  : '_' { BinderWildcard () $1 }
  | var '@' binderAtom { BinderNamed () $1 $2 $3 }
  | properIdent { BinderConstructor () $1 [] }
  | boolean { uncurry (BinderBoolean ()) $1 }
  | char { uncurry (BinderChar ()) $1 }
  | string { uncurry (BinderString ()) $1 }
  | number { uncurry (BinderNumber ()) $1 }
  | array(binder) { BinderArray () $1 }
  | record(binder) { BinderRecord () $1 }
  | '(' binder ')' { BinderParens () (Wrapped $1 $2 $3) }

caseBranch :: { (Separated (Binder ()), Guarded ()) }
  : sep(binder, ',') guarded('->') { ($1, $2) }

guarded(a) :: { Guarded () }
  : a exprWhere { Unconditional $1 $2 }
  | many(guardedExpr(a)) { Guarded $1 }

guardedExpr(a) :: { GuardedExpr () }
  : '|' sep(patternGuard, ',') a expr { GuardedExpr $1 $2 $3 $4 }

patternGuard :: { PatternGuard () }
  : expr { PatternGuard Nothing $1 }
  -- Binder is parsed as an expr due to reduce/reduce conflicts between the
  -- two syntaxes. We would have to inline most of the expr and binder
  -- grammar to resolve it.
  | expr '<-' expr1 { PatternGuard (Just (toBinder $1, $2)) $3 }

doStatement :: { DoStatement () }
  : 'let' '\{' manySep(letBinding, '\;') '\}' { DoLet $1 $3 }
  | expr { DoDiscard $1 }
  -- Binder is parsed as an expr due to reduce/reduce conflicts between the
  -- two syntaxes. We would have to inline most of the expr and binder
  -- grammar to resolve it.
  | expr '<-' expr { DoBind (toBinder $1) $2 $3 }

module :: { Module () }
  : 'module' proper exports 'where' '\{' moduleDecls '\}'
      { uncurry (Module () $1 $2 $3 $4) $6 }

moduleDecls :: { ([ImportDecl ()], [Declaration ()]) }
  : {- empty -} { ([], []) }
  | manySep(moduleDecl, '\;') { toModuleDecls($1) }

moduleDecl :: { Either (ImportDecl ()) (Declaration ()) }
  : importDecl { Left $1 }
  | decl { Right $1 }

exports :: { Maybe (DelimitedNonEmpty (Export ())) }
  : {- empty -} { Nothing }
  | '(' sep(export, ',') ')' { Just (Wrapped $1 $2 $3) }

export :: { Export () }
  : ident { ExportValue () $1 }
  | '(' symbol ')' { ExportOp () (Wrapped $1 $2 $3) }
  | properIdent { ExportType () $1 Nothing }
  | properIdent dataMembers { ExportType () $1 (Just $2) }
  | 'type' '(' symbol ')' { ExportTypeOp () $1 (Wrapped $2 $3 $4) }
  | 'class' properIdent { ExportClass () $1 $2 }
  | 'kind' properIdent { ExportKind () $1 $2 }
  | 'module' proper { ExportModule () $1 $2 }

dataMembers :: { Wrapped (Maybe (DataMembers ())) }
 : '(' ')' { Wrapped $1 Nothing $2 }
 | '(' '..' ')' { Wrapped $1 (Just (DataAll () $2)) $3 }
 | '(' sep(properIdent, ',') ')' { Wrapped $1 (Just (DataEnumerated () $2)) $3 }

importDecl :: { ImportDecl () }
  : 'import' proper imports { ImportDecl () $1 $2 $3 Nothing }
  | 'import' proper imports 'as' proper { ImportDecl () $1 $2 $3 (Just ($4, $5)) }

imports :: { Maybe (DelimitedNonEmpty (Import ())) }
  : {- empty -} { Nothing }
  | '(' sep(import, ',') ')' { Just (Wrapped $1 $2 $3) }

import :: { Import () }
  : ident { ImportValue () $1 }
  | '(' symbol ')' { ImportOp () (Wrapped $1 $2 $3) }
  | properIdent { ImportType () $1 Nothing }
  | properIdent dataMembers { ImportType () $1 (Just $2) }
  | 'type' '(' symbol ')' { ImportTypeOp () $1 (Wrapped $2 $3 $4) }
  | 'class' properIdent { ImportClass () $1 $2 }
  | 'kind' properIdent { ImportKind () $1 $2 }

decl :: { Declaration () }
  : dataHead { DeclData () $1 Nothing }
  | dataHead '=' sep(dataCtor, '|') { DeclData () $1 (Just ($2, $3)) }
  | typeHead '=' type { DeclType () $1 $2 $3 }
  | newtypeHead '=' properIdent type { DeclNewtype () $1 $2 $3 $4 }
  | classHead { DeclClass () $1 Nothing }
  | classHead 'where' '\{' manySep(classMember, '\;') '\}' { DeclClass () $1 (Just ($2, $4)) }
  | instHead { DeclInstance () $1 Nothing }
  | instHead 'where' '\{' manySep(instBinding, '\;') '\}' { DeclInstance () $1 (Just ($2, $4)) }
  | 'derive' instHead { DeclDerive () $1 Nothing $2 }
  | 'derive' 'newtype' instHead { DeclDerive () $1 (Just $2) $3 }
  | ident '::' type { DeclSignature () (Labeled $1 $2 $3) }
  | ident manyOrEmpty(binder) guarded('=') { DeclValue () (ValueBindingFields $1 $2 $3) }
  | fixity { DeclFixity () $1 }
  | 'foreign' 'import' foreign { DeclForeign () $1 $2 $3 }

dataHead :: { DeclDataHead () }
  : 'data' properIdent manyOrEmpty(typeVarBinding) { DeclDataHead $1 $2 $3 }

typeHead :: { DeclDataHead () }
  : 'type' properIdent manyOrEmpty(typeVarBinding) { DeclDataHead $1 $2 $3 }

newtypeHead :: { DeclDataHead () }
  : 'newtype' properIdent manyOrEmpty(typeVarBinding) { DeclDataHead $1 $2 $3 }

dataCtor :: { DeclDataCtor () }
  : properIdent manyOrEmpty(type) { DeclDataCtor () $1 $2 }

classHead :: { DeclClassHead () }
  : 'class' classNameAndVars fundeps { DeclClassHead $1 Nothing (fst $2) (snd $2) $3 }
  -- We need to inline constraints due to the reduce/reduce conflict between
  -- the class name and vars and constraint syntax.
  | 'class' classNameAndVars '<=' classNameAndVars fundeps
      { DeclClassHead $1
          (Just (One (foldl' (TypeApp ()) (TypeVar () (fst $2)) (fmap varToType (snd $2))), $3))
          (fst $4)
          (snd $4)
          $5 }
  | 'class' '(' sep(constraint, ',') ')' '<=' classNameAndVars fundeps
      { DeclClassHead $1 (Just (Many (Wrapped $2 $3 $4), $5)) (fst $6) (snd $6) $7 }

classNameAndVars :: { (Ident, [TypeVarBinding ()]) }
  : properIdent manyOrEmpty(typeVarBinding) { ($1, $2) }

fundeps :: { Maybe (SourceToken, Separated DeclClassFundep) }
  : {- empty -} { Nothing }
  | '|' sep(fundep, ',') { Just ($1, $2) }

fundep :: { DeclClassFundep }
  : '->' many(ident) { DeclClassFundep [] $1 $2 }
  | many(ident) '->' many(ident) { DeclClassFundep $1 $2 $3 }

classMember :: { Labeled (Type ()) }
  : ident '::' type { Labeled $1 $2 $3 }

instHead :: { DeclInstanceHead () }
  : 'instance' ident '::' constraints '=>' properIdent manyOrEmpty(typeAtom)
      { DeclInstanceHead $1 $2 $3 (Just ($4, $5)) $6 $7 }
  | 'instance' ident '::' properIdent manyOrEmpty(typeAtom)
      { DeclInstanceHead $1 $2 $3 Nothing $4 $5 }

constraints :: { OneOrDelimited (Type ()) }
  : constraint { One $1 }
  | '(' sep(constraint, ',') ')' { Many (Wrapped $1 $2 $3) }

constraint :: { Type () }
  : properIdent { TypeConstructor () $1 }
  | properIdent many(typeAtom) { foldl' (TypeApp ()) (TypeConstructor () $1) $2 }

instBinding :: { InstanceBinding () }
  : ident '::' type { InstanceBindingSignature () (Labeled $1 $2 $3) }
  | ident manyOrEmpty(binder) guarded('=') { InstanceBindingName () (ValueBindingFields $1 $2 $3) }

fixity :: { DeclFixityFields () }
  : infix int ident 'as' symbol { DeclFixityFields $1 $2 Nothing $3 $4 $5 }
  | infix int 'type' properIdent 'as' symbol { DeclFixityFields $1 $2 (Just $3) $4 $5 $6 }

infix :: { SourceToken }
  : 'infix' { $1 }
  | 'infixl' { $1 }
  | 'infixr' { $1 }

foreign :: { Foreign () }
  : ident '::' type { ForeignValue (Labeled $1 $2 $3) }
  | 'data' properIdent '::' kind { ForeignData $1 (Labeled $2 $3 $4) }
  | 'kind' properIdent { ForeignKind $1 $2 }
