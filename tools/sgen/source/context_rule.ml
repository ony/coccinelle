module Ast0 = Ast0_cocci
module Ast = Ast_cocci
module MV = Meta_variable

(* ------------------------------------------------------------------------- *)

(* Generates a context mode rule with positions and stars!
 * May generate an extra disjunction rule if the original rule calls for it.
 *
 * Invariants:
 *  - The rule contains */+/- ! No need for context generation otherwise ...
 *  - The rule's name or new name has to be valid! no whitespace funny business
 *  - (however, it can be <default rule name><number> at this point).
 *)

(* ------------------------------------------------------------------------- *)
(* CONTEXT RULE GENERATION FUNCTIONS *)

type t = (Rule_header.t * Rule_body.t) list

let generate ~context_mode ~disj_map ~new_name ~rule =
  match rule with
  | Ast0.InitialScriptRule (nm,_,_,_,_)
  | Ast0.FinalScriptRule (nm,_,_,_,_)
  | Ast0.ScriptRule (nm,_,_,_,_,_) ->
      failwith
        ("Internal error: Can't generate a context rule for a script rule! " ^
         "The rule is: " ^ nm)

  | Ast0.CocciRule ((minus_rule,_,(isos,drop_isos,deps,old_nm,exists)),_,_) ->

      (* generated rule names *)
      let context_nm = Globals.get_context_name ~context_mode new_name in
      let disj_nm = Globals.get_disj_name new_name in

      (* extract all metavariables from the rule. Call on original rule name
       * in order to avoid rule inheritance.
       *)
      let meta_vars = MV.unparse ~minus_rule ~rule_name:old_nm in

      (* function for generating a header with virtual rule dependencies *)
      let deps = Globals.add_context_dependency ~context_mode deps in
      let rh_fn = Rule_header.generate ~isos ~drop_isos ~deps ~meta_vars in

      (* generated context rule body and positions *)
      let (pos, (context_body, disj)) =
        Rule_body.generate ~context_mode ~disj_map ~minus_rule in

      let _ = if List.length pos = 0 then failwith
        ("MEGA ERROR: Congratulations! You managed to write a Coccinelle " ^
         "rule that sgen was unable to add a position to! The rule is \"" ^
         old_nm ^ "\".") in

      (* the added position metavariables in local scope (for headers) *)
      let pos_mv = List.map (MV.make ~typ:"position ") pos in

      (* the added position metavariables in inherited scope (for returning) *)
      let pos_inh = List.map (MV.inherit_rule ~new_rule:context_nm) pos_mv in

      (* check if any extra generated disj rule *)
      match disj with
      | None ->
          let context_header =
            rh_fn ~exists ~rule_name:context_nm ~meta_pos:pos_mv in
          ([(context_header, context_body)], pos_inh)

      | Some disj_body ->
          (* context rule has no stars, therefore "exists" in header *)
          let context_header =
            rh_fn ~rule_name:context_nm ~exists:Ast.Exists ~meta_pos:pos_mv in
          let disj_header =
            rh_fn ~rule_name:disj_nm ~exists ~meta_pos:pos_inh in
          ([(context_header, context_body); (disj_header, disj_body)], pos_inh)

let print out l =
  List.iter (fun (rh,rb) -> Rule_header.print out rh; Rule_body.print out rb) l
