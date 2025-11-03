{
  (* Simple OCamllex lexer for testing *)
  open Parser
}

let digit = ['0'-'9']
let letter = ['a'-'z' 'A'-'Z']
let ident = letter (letter | digit | '_')*
let whitespace = [' ' '\t' '\n' '\r']

rule token = parse
  | whitespace+ { token lexbuf }
  | digit+ as num { INT (int_of_string num) }
  | ident as id { IDENT id }
  | '+' { PLUS }
  | '-' { MINUS }
  | '*' { STAR }
  | '/' { SLASH }
  | '(' { LPAREN }
  | ')' { RPAREN }
  | eof { EOF }
  | _ { failwith "Unexpected character" }

and comment = parse
  | "*)" { token lexbuf }
  | eof { failwith "Unterminated comment" }
  | _ { comment lexbuf }
