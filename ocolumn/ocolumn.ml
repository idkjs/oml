(* ocolumn: a version of *BSD's column(1) that doesn't dump core on long lines
   Keith Waclena <http://www.lib.uchicago.edu/keith/>
*)

open Utils
open Printf

(* "for programs that run for a short time but allocate like crazy, *)
(* the default value of Gc.space_overhead is a little too low and causes *)
(* the garbage collector to work unnecessarily hard" *)
let _ = Gc.set { (Gc.get()) with Gc.space_overhead = 100 }

(* print usage message *)
let usage = sprintf "Usage: %s [-i STR] [-m] [-o STR] [-r REGEXP] [-s STR] [-t] [--] file ..."

(* cmdline parameters and related *)

let isep = ref None			(* input field separator *)
let merge = ref false			(* merge adjacent empty fields *)
let osep = ref "  "			(* output field separator *)
let regexp = ref (Some "\t")		(* regular expression split *)
let compiled = ref (Pcre.regexp "")	(* compiled version of !regexp *)
let names = ref []			(* filenames *)
let sepopts = ref 0

let get = function
  | Some x -> x
  | None   -> raise Not_found

(* speclist for Arg.parse cmdline parsing *)
let speclist = [
  ("-i", Arg.String (fun s -> isep := Some s; regexp := None; incr sepopts),
   "STR: input field separator (default: '%s')");
  ("-m", Arg.Unit   (fun () -> merge := true),
   (sprintf ": merge adjacent empty fields (like awk; default: %s)" (if !merge then "true" else "false")));
  ("-o", Arg.String (fun s -> osep := s),
   (sprintf "STR: output field separator (default: '%s')" (String.escaped !osep)));
  ("-r", Arg.String (fun s -> regexp := Some s; isep := None; incr sepopts),
   "REGEXP: field separator as regular expression");
  ("-s", Arg.String (fun s -> isep := Some s; osep := s; regexp := None; incr sepopts),
   "STR: field separator (sets -i and -o)");
  ("-t", Arg.Unit   (fun () -> ()),
   ": noop for compatibility with BSD column");
  ("--", Arg.Rest   (fun name -> names := !names @ [name]),
   ": stop interpreting options");
]

(* return maximum int in a list of ints *)
let maxwidth = List.fold_left max 0

(* our most important data structure is an int list list, representing *)
(* a matrix of column widths; the matrix must be rectangular.  maxcols *)
(* takes such a matrix and reduces it to an int list indicating the *)
(* max width in each column of the matrix.  if the matrix has N *)
(* rows and M columns, the result of maxcols is a list of length M *)
let maxcols = (List.map maxwidth) & transpose

let splitter str =
  match !regexp with
    | Some r -> Pcre.split ~rex:!compiled ~max:(-1) str
    | None   -> split ~merge:!merge (get !isep) str

(* columnate files in argv according to widths in widths
   widths is a list of integer max column widths (such as returned by maxcols)
   argv is a list of filenames
 *)
let columnate widths argv =
  (* columnate (as above) one file (open on chan) *)
  let columnatechan chan =
    (* given list of strings (ie fields) widen each one and join into a
       string, trimming trailing spaces *)
    let widenfields fields =
      (* pad s out to n chars with spaces *)
      let widen n s =
	let len = String.length s in
	  assert (len <= n);
	  s ^ (String.make (n-len) ' ')
      in
	trimright ' ' (String.concat !osep (List.map2 widen widths fields))
    in 
      (* widen fields of a line and print result *)
    let widenprint line = print_endline (widenfields (splitter line))
    in 
      iterlines widenprint chan
  in
    List.iter (with_open_in_file columnatechan) argv

(* return widths of fields in line as list of ints *)
let linewidths len line =
  let fields = List.map String.length (splitter line) in
    match len with
      | Some n ->
	  if List.length fields <> n
	  then
	    let err = (sprintf "non-rectangular data (NOT all lines have %d fields)" n) in
	      raise (Invalid_argument err)
	  else fields
      | None -> fields

(* return an int list list of all "linewidths" in chan.  a *)
(* "linewidth" is an int list representing the widths of all the *)
(* fields in a given line; a list of such linewidths represents the *)
(* column widths of all the lines in a file (open on chan) *)
let getlinewidths chan =
  let widths1 = linewidths None (input_line chan) in
  let n = List.length widths1 in
    widths1::(maplines (linewidths (Some n)) chan)

(* get max widths of columns in file open on chan as list of ints *)
let getcolwidths = maxcols & getlinewidths 

(* get max widths across all named files *)
let getfilewidths argv = maxcols (List.map (with_open_in_file getcolwidths) argv)

(* check command line options *)
let checkopts () =
  match !regexp with
    | Some r ->
	if !merge then raise (Arg.Bad "-m and -r are incompatible");
	if !sepopts > 1 then raise (Arg.Bad "-r is incompatible with -i and -s");
	compiled := Pcre.regexp r;
	()
    | None ->
	()

(* main routine: handle cmdline options and args, and columnate *)
let main () =
  let collect name = names := !names @ [name] in
  let msg = (usage (basename Sys.argv.(0))) in
  let _ = Arg.parse speclist collect msg in
  let argv = (tmpstdin (if !names = [] then ["-"] else !names)) in
    checkopts ();
    columnate (getfilewidths argv) argv

let _ = main ()
