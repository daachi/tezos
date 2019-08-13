(*****************************************************************************)
(*                                                                           *)
(* Open Source License                                                       *)
(* Copyright (c) 2018 Dynamic Ledger Solutions, Inc. <contact@tezos.com>     *)
(* Copyright (c) 2019 Nomadic Labs <contact@nomadic-labs.com>                *)
(*                                                                           *)
(* Permission is hereby granted, free of charge, to any person obtaining a   *)
(* copy of this software and associated documentation files (the "Software"),*)
(* to deal in the Software without restriction, including without limitation *)
(* the rights to use, copy, modify, merge, publish, distribute, sublicense,  *)
(* and/or sell copies of the Software, and to permit persons to whom the     *)
(* Software is furnished to do so, subject to the following conditions:      *)
(*                                                                           *)
(* The above copyright notice and this permission notice shall be included   *)
(* in all copies or substantial portions of the Software.                    *)
(*                                                                           *)
(* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR*)
(* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,  *)
(* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL   *)
(* THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER*)
(* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING   *)
(* FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER       *)
(* DEALINGS IN THE SOFTWARE.                                                 *)
(*                                                                           *)
(*****************************************************************************)

open Protocol

let group =
  { Clic.name = "scripts" ;
    title = "Commands for managing the library of known scripts" }

open Tezos_micheline
open Client_proto_programs
open Client_proto_args
open Client_proto_contracts

let commands () =
  let open Clic in
  let show_types_switch =
    switch
      ~long:"details"
      ~short:'v'
      ~doc:"show the types of each instruction"
      () in
  let emacs_mode_switch =
    switch
      ~long:"emacs"
      ?short:None
      ~doc:"output in `michelson-mode.el` compatible format"
      () in
  let trace_stack_switch =
    switch
      ~long:"trace-stack"
      ~doc:"show the stack after each step"
      () in
  let amount_arg =
    Client_proto_args.tez_arg
      ~parameter:"amount"
      ~doc:"amount of the transfer in \xEA\x9C\xA9"
      ~default:"0.05" in
  let source_arg =
    ContractAlias.destination_arg
      ~name: "source"
      ~doc: "name of the source (i.e. SENDER) contract for the transaction"
      () in
  let payer_arg =
    ContractAlias.destination_arg
      ~name: "payer"
      ~doc: "name of the payer (i.e. SOURCE) contract for the transaction"
      () in
  let custom_gas_flag =
    arg
      ~long:"gas"
      ~short:'G'
      ~doc:"Initial quantity of gas for typechecking and execution"
      ~placeholder:"gas"
      (parameter (fun _ctx str ->
           try
             let v = Z.of_string str in
             assert Compare.Z.(v >= Z.zero) ;
             return v
           with _ -> failwith "invalid gas limit (must be a positive number)")) in
  let resolve_max_gas cctxt block = function
    | None ->
        Alpha_services.Constants.all cctxt
          (cctxt#chain, block) >>=? fun { parametric = {
            hard_gas_limit_per_operation ; _
          } ; _ } ->
        return hard_gas_limit_per_operation
    | Some gas -> return gas in
  let data_parameter =
    Clic.parameter (fun _ data ->
        Lwt.return (Micheline_parser.no_parsing_error
                    @@ Michelson_v1_parser.parse_expression data)) in
  let bytes_parameter ~name ~desc =
    Clic.param ~name ~desc Client_proto_args.bytes_parameter
  in
  let signature_parameter =
    Clic.parameter
      (fun _cctxt s ->
         match Signature.of_b58check_opt s with
         | Some s -> return s
         | None -> failwith "Not given a valid signature") in
  [

    command ~group ~desc: "Lists all scripts in the library."
      no_options
      (fixed [ "list" ; "known" ; "scripts" ])
      (fun () (cctxt : Protocol_client_context.full) ->
         Program.load cctxt >>=? fun list ->
         Lwt_list.iter_s (fun (n, _) -> cctxt#message "%s" n) list >>= fun () ->
         return_unit) ;

    command ~group ~desc: "Add a script to the library."
      (args1 (Program.force_switch ()))
      (prefixes [ "remember" ; "script" ]
       @@ Program.fresh_alias_param
       @@ Program.source_param
       @@ stop)
      (fun force name hash cctxt ->
         Program.of_fresh cctxt force name >>=? fun name ->
         Program.add ~force cctxt name hash) ;

    command ~group ~desc: "Remove a script from the library."
      no_options
      (prefixes [ "forget" ; "script" ]
       @@ Program.alias_param
       @@ stop)
      (fun () (name, _) cctxt -> Program.del cctxt name) ;

    command ~group ~desc: "Display a script from the library."
      no_options
      (prefixes [ "show" ; "known" ; "script" ]
       @@ Program.alias_param
       @@ stop)
      (fun () (_, program) (cctxt : Protocol_client_context.full) ->
         Program.to_source program >>=? fun source ->
         cctxt#message "%s\n" source >>= fun () ->
         return_unit) ;

    command ~group ~desc: "Ask the node to run a script."
      (args7 trace_stack_switch amount_arg source_arg payer_arg
         no_print_source_flag custom_gas_flag entrypoint_arg)
      (prefixes [ "run" ; "script" ]
       @@ Program.source_param
       @@ prefixes [ "on" ; "storage" ]
       @@ Clic.param ~name:"storage" ~desc:"the storage data"
         data_parameter
       @@ prefixes [ "and" ; "input" ]
       @@ Clic.param ~name:"input" ~desc:"the input data"
         data_parameter
       @@ stop)
      (fun
        (trace_exec, amount, source, payer, no_print_source, gas, entrypoint)
        program storage input cctxt ->
        let source = Option.map ~f:snd source in
        let payer = Option.map ~f:snd payer in
        Lwt.return @@ Micheline_parser.no_parsing_error program >>=? fun program ->
        let show_source = not no_print_source in
        (if trace_exec then
           trace cctxt ~chain:cctxt#chain ~block:cctxt#block
             ~amount ~program ~storage ~input ?source ?payer ?gas ?entrypoint () >>= fun res ->
           print_trace_result cctxt ~show_source ~parsed:program res
         else
           run cctxt ~chain:cctxt#chain ~block:cctxt#block
             ~amount ~program ~storage ~input ?source ?payer ?gas ?entrypoint () >>= fun res ->
           print_run_result cctxt ~show_source ~parsed:program res)) ;

    command ~group ~desc: "Ask the node to typecheck a script."
      (args4 show_types_switch emacs_mode_switch no_print_source_flag custom_gas_flag)
      (prefixes [ "typecheck" ; "script" ]
       @@ Program.source_param
       @@ stop)
      (fun (show_types, emacs_mode, no_print_source, original_gas) program cctxt ->
         match program with
         | program, [] ->
             resolve_max_gas cctxt cctxt#block original_gas >>=? fun original_gas ->
             typecheck_program cctxt ~chain:cctxt#chain ~block:cctxt#block ~gas:original_gas program >>= fun res ->
             print_typecheck_result
               ~emacs:emacs_mode
               ~show_types
               ~print_source_on_error:(not no_print_source)
               program
               res
               cctxt
         | res_with_errors when emacs_mode ->
             cctxt#message
               "(@[<v 0>(types . ())@ (errors . %a)@])"
               Michelson_v1_emacs.report_errors res_with_errors >>= fun () ->
             return_unit
         | (parsed, errors) ->
             cctxt#message "%a"
               (fun ppf () ->
                  Michelson_v1_error_reporter.report_errors
                    ~details:(not no_print_source) ~parsed
                    ~show_source:(not no_print_source)
                    ppf errors) () >>= fun () ->
             cctxt#error "syntax error in program"
      ) ;

    command ~group ~desc: "Ask the node to typecheck a data expression."
      (args2 no_print_source_flag custom_gas_flag)
      (prefixes [ "typecheck" ; "data" ]
       @@ Clic.param ~name:"data" ~desc:"the data to typecheck"
         data_parameter
       @@ prefixes [ "against" ; "type" ]
       @@ Clic.param ~name:"type" ~desc:"the expected type"
         data_parameter
       @@ stop)
      (fun (no_print_source, custom_gas) data ty cctxt ->
         resolve_max_gas cctxt cctxt#block custom_gas >>=? fun original_gas ->
         Client_proto_programs.typecheck_data cctxt
           ~chain:cctxt#chain ~block:cctxt#block
           ~gas:original_gas ~data ~ty () >>= function
         | Ok gas ->
             cctxt#message "@[<v 0>Well typed@,Gas remaining: %a@]"
               Alpha_context.Gas.pp gas >>= fun () ->
             return_unit
         | Error errs ->
             cctxt#warning "%a"
               (Michelson_v1_error_reporter.report_errors
                  ~details:false
                  ~show_source:(not no_print_source)
                  ?parsed:None) errs >>= fun () ->
             cctxt#error "ill-typed data") ;

    command ~group
      ~desc: "Ask the node to pack a data expression.\n\
              The returned hash is the same as what Michelson \
              instruction `PACK` would have produced.\n\
              Also displays the result of hashing this packed data \
              with `BLAKE2B`, `SHA256` or `SHA512` instruction."
      (args1 custom_gas_flag)
      (prefixes [ "hash" ; "data" ]
       @@ Clic.param ~name:"data" ~desc:"the data to hash"
         data_parameter
       @@ prefixes [ "of" ; "type" ]
       @@ Clic.param ~name:"type" ~desc:"type of the data"
         data_parameter
       @@ stop)
      (fun custom_gas data typ cctxt ->
         resolve_max_gas cctxt cctxt#block custom_gas >>=? fun original_gas ->
         Alpha_services.Helpers.Scripts.pack_data cctxt (cctxt#chain, cctxt#block)
           (data.expanded, typ.expanded, Some original_gas) >>= function
         | Ok (bytes, remaining_gas) ->
             let hash = Script_expr_hash.hash_bytes [ bytes ] in
             cctxt#message
               "Raw packed data: 0x%a@,\
                Script-expression-ID-Hash: %a@,\
                Raw Script-expression-ID-Hash: 0x%a@,\
                Ledger Blake2b hash: %s@,\
                Raw Sha256 hash: 0x%a@,\
                Raw Sha512 hash: 0x%a@,\
                Gas remaining: %a"
               MBytes.pp_hex bytes
               Script_expr_hash.pp hash
               MBytes.pp_hex (Script_expr_hash.to_bytes hash)
               (Base58.raw_encode Blake2B.(hash_bytes [bytes] |> to_string))
               MBytes.pp_hex (Environment.Raw_hashes.sha256 bytes)
               MBytes.pp_hex (Environment.Raw_hashes.sha512 bytes)
               Alpha_context.Gas.pp remaining_gas >>= fun () ->
             return_unit
         | Error errs ->
             cctxt#warning "%a"
               (Michelson_v1_error_reporter.report_errors
                  ~details:false
                  ~show_source:false
                  ?parsed:None)
               errs  >>= fun () ->
             cctxt#error "ill-formed data") ;

    command ~group
      ~desc: "Parse a byte sequence (in hexadecimal notation) as a \
              data expression, as per Michelson instruction `UNPACK`."
      Clic.no_options
      (prefixes [ "unpack" ; "michelson" ; "data" ]
       @@ bytes_parameter ~name:"bytes" ~desc:"the packed data to parse"
       @@ stop)
      (fun () bytes cctxt ->
         begin
           if MBytes.get bytes 0 != '\005' then
             failwith "Not a piece of packed Michelson data (must start with `0x05`)"
           else return_unit
         end >>=? fun () ->
         (* Remove first byte *)
         let bytes = MBytes.sub bytes 1 ((MBytes.length bytes) - 1) in
         match Data_encoding.Binary.of_bytes Alpha_context.Script.expr_encoding bytes with
         | None -> failwith "Could not decode bytes"
         | Some expr ->
             begin
               cctxt#message "%a" Michelson_v1_printer.print_expr_unwrapped expr >>= fun () ->
               return_unit
             end) ;

    command ~group
      ~desc: "Sign a raw sequence of bytes and display it using the \
              format expected by Michelson instruction \
              `CHECK_SIGNATURE`."
      no_options
      (prefixes [ "sign" ; "bytes" ]
       @@ bytes_parameter ~name:"data" ~desc:"the raw data to sign"
       @@ prefixes [ "for" ]
       @@ Client_keys.Secret_key.source_param
       @@ stop)
      (fun () bytes sk cctxt ->
         Client_keys.sign cctxt sk bytes >>=? fun signature ->
         cctxt#message "Signature: %a" Signature.pp signature >>= fun () ->
         return_unit) ;

    command ~group
      ~desc: "Check the signature of a byte sequence as per Michelson \
              instruction `CHECK_SIGNATURE`."
      (args1 (switch ~doc:"Use only exit codes" ~short:'q' ~long:"quiet" ()))
      (prefixes [ "check" ; "that" ]
       @@ bytes_parameter ~name:"bytes" ~desc:"the signed data"
       @@ prefixes [ "was" ; "signed" ; "by" ]
       @@ Client_keys.Public_key.alias_param
         ~name:"key"
       @@ prefixes [ "to" ; "produce" ]
       @@ Clic.param ~name:"signature" ~desc:"the signature to check"
         signature_parameter
       @@ stop)
      (fun quiet bytes (_, (key_locator, _)) signature
        (cctxt : #Protocol_client_context.full) ->
        Client_keys.check key_locator signature bytes >>=? function
        | false -> cctxt#error "invalid signature"
        | true ->
            if quiet then
              return_unit
            else
              cctxt#message "Signature check successfull." >>= fun () ->
              return_unit
      ) ;

    command ~group ~desc: "Ask the type of an entrypoint of a script."
      (args2 emacs_mode_switch no_print_source_flag)
      (prefixes [ "get" ; "script" ;  "entrypoint"; "type" ; "of"   ]
       @@ Clic.string ~name:"entrypoint" ~desc:"the entrypoint to describe"
       @@ prefixes [ "for" ]
       @@ Program.source_param
       @@ stop)
      (fun (emacs_mode, no_print_source) entrypoint program cctxt ->
         match program with
         | program, [] ->
             entrypoint_type
               cctxt ~chain:cctxt#chain ~block:cctxt#block program ~entrypoint >>= fun entrypoint_type ->
             print_entrypoint_type
               ~emacs:emacs_mode
               ~show_source:(not no_print_source)
               ~parsed:program
               ~entrypoint
               cctxt
               entrypoint_type
         | res_with_errors when emacs_mode ->
             cctxt#message
               "(@[<v 0>(entrypoint . ())@ (errors . %a)@])"
               Michelson_v1_emacs.report_errors res_with_errors >>= fun () ->
             return_unit
         | (parsed, errors) ->
             cctxt#message "%a"
               (fun ppf () ->
                  Michelson_v1_error_reporter.report_errors
                    ~details:(not no_print_source) ~parsed
                    ~show_source:(not no_print_source)
                    ppf errors) () >>= fun () ->
             cctxt#error "syntax error in program"
      ) ;

    command ~group ~desc: "Ask the node to list the entrypoints of a script."
      (args2 emacs_mode_switch no_print_source_flag)
      (prefixes [ "get" ; "script" ; "entrypoints" ; "for" ]
       @@ Program.source_param
       @@ stop)
      (fun (emacs_mode, no_print_source) program cctxt ->
         match program with
         | program, [] ->
             list_entrypoints
               cctxt ~chain:cctxt#chain ~block:cctxt#block program >>= fun entrypoints ->
             print_entrypoints_list
               ~emacs:emacs_mode
               ~show_source:(not no_print_source)
               ~parsed:program
               cctxt
               entrypoints
         | res_with_errors when emacs_mode ->
             cctxt#message
               "(@[<v 0>(entrypoints . ())@ (errors . %a)@])"
               Michelson_v1_emacs.report_errors res_with_errors >>= fun () ->
             return_unit
         | (parsed, errors) ->
             cctxt#message "%a"
               (fun ppf () ->
                  Michelson_v1_error_reporter.report_errors
                    ~details:(not no_print_source) ~parsed
                    ~show_source:(not no_print_source)
                    ppf errors) () >>= fun () ->
             cctxt#error "syntax error in program"
      ) ;

    command ~group ~desc: "Ask the node to list the unreachable paths\
                           in a script's parameter type."
      (args2 emacs_mode_switch no_print_source_flag)
      (prefixes [ "get" ; "script" ; "unreachable" ; "paths" ; "for" ]
       @@ Program.source_param
       @@ stop)
      (fun (emacs_mode, no_print_source) program cctxt ->
         match program with
         | program, [] ->
             list_unreachables
               cctxt ~chain:cctxt#chain ~block:cctxt#block program >>= fun entrypoints ->
             print_unreachables
               ~emacs:emacs_mode
               ~show_source:(not no_print_source)
               ~parsed:program
               cctxt
               entrypoints
         | res_with_errors when emacs_mode ->
             cctxt#message
               "(@[<v 0>(entrypoints . ())@ (errors . %a)@])"
               Michelson_v1_emacs.report_errors res_with_errors >>= fun () ->
             return_unit
         | (parsed, errors) ->
             cctxt#message "%a"
               (fun ppf () ->
                  Michelson_v1_error_reporter.report_errors
                    ~details:(not no_print_source) ~parsed
                    ~show_source:(not no_print_source)
                    ppf errors) () >>= fun () ->
             cctxt#error "syntax error in program"
      ) ;
  ]
