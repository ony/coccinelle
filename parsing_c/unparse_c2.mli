open Common

type ppmethod = PPnormal | PPviastr

(* program -> output filename (often "/tmp/output.c") -> unit *) 
val pp_program : 
  (Parse_c.toplevel2 * ppmethod) list -> filename -> unit
