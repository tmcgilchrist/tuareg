/* Simple Menhir grammar for testing */

%token <int> INT
%token <string> ID
%token PLUS MINUS STAR SLASH
%token LPAREN RPAREN
%token EOF

%left PLUS MINUS
%left STAR SLASH

%start <int> main

%%

main:
  | e = expr EOF { e }

expr:
  | i = INT { i }
  | LPAREN e = expr RPAREN { e }
  | e1 = expr PLUS e2 = expr { e1 + e2 }
  | e1 = expr MINUS e2 = expr { e1 - e2 }
  | e1 = expr STAR e2 = expr { e1 * e2 }
  | e1 = expr SLASH e2 = expr { e1 / e2 }

