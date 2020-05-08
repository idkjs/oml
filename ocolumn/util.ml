exception Finally of exn

(* infix function composition *)
let (&) f g x = f (g x)

let time n thunk =
  let time' thunk =
    let t = Sys.time () in
      ignore (thunk ());
      Sys.time () -. t
  in
  let rec loop n i thunk =
    if i = 0
    then 0.0
    else begin
      Gc.full_major (); Gc.compact ();
      time' thunk +. (loop n (i-1) thunk)
    end
  in
    (loop (float n) n thunk) /. (float n)

(* python's try ... finally .. *)
let finalize body final =
  try
    begin
      try
	let result = body () in
	  begin
	    final ();
	    result
	  end
      with exc ->
	raise (Finally exc)
    end
  with Finally exc ->
    begin
      final ();
      raise exc
    end

let with_open_in_file ?(isstdin=(fun f -> f = "-" || f = "")) f filename =
  let chan = if isstdin filename then stdin else open_in filename in
    finalize (
      fun () ->
	f chan
    ) (
      fun () ->
	close_in chan
    )

let with_open_out_file ?(isstdout=(fun f -> f = "-" || f = "")) f filename =
  let chan = if isstdout filename then stdout else open_out filename in
    finalize (
      fun () ->
	f chan
    ) (
      fun () ->
	close_out chan
    )

let clone ?(bufsize=32 * 1024) inp out =
  let buf = String.create bufsize in
  let rec clone' () =
    let len = input inp buf 0 bufsize in
      if len = 0
      then () (* eof *)
      else begin
	output out buf 0 len;
	clone' ()
      end
  in 
    finalize (
      fun () ->
	clone' ()
    ) (
      fun () ->
	close_out out
    )

let tmpstdin ?(isstdin=(fun f -> f = "-" || f = "")) argv =
  let me = Filename.basename Sys.argv.(0) in
  let prefix =
    try
      Filename.chop_extension me
    with Invalid_argument _ ->
      me
  in
  let rec cloneit isstdin cloned tmpfile = function
      | [] -> tmpfile
      | f::rest when isstdin f ->
	  if not cloned then
	    begin
	      let tmpfile, out = (Filename.open_temp_file prefix "") in
		clone stdin out;
		at_exit (fun () -> Sys.remove tmpfile);
		cloneit isstdin true tmpfile rest
	    end
	  else
	    cloneit isstdin false "" rest
      | _::rest -> cloneit isstdin cloned "" rest
  in
  let rec fixit isstdin tmpfile = function
    | [] -> []
    | f::rest when isstdin f -> tmpfile::fixit isstdin tmpfile rest
    | f::rest -> f::fixit isstdin tmpfile rest
  in
    fixit isstdin (cloneit isstdin false "" argv) argv

(* tail-recursive *)
let explode str =
  let rec explode' n str acc =
    if n < 0
    then acc
    else explode' (n-1) str (str.[n]::acc)
  in
    explode' ((String.length str)-1) str []

(* tail-recursive *)
let implode l =
  let res = String.create (List.length l) in
  let rec imp i = function
    | [] -> res
    | c :: l -> res.[i] <- c; imp (i + 1) l in
    imp 0 l

(* tail-recursive *)
let rec dropwhile f = function
  | [] -> []
  | hd::tl when f hd -> dropwhile f tl
  | list -> list

(* NOT tail-recursive *)
let readlines chan =
  let rec readlines' chan lines =
    try
      readlines' chan ((input_line chan)::lines)
    with End_of_file ->
      List.rev lines
  in
    readlines' chan []

let rec getline chan =			(* non-exceptional version of input_line *)
  try 
    Some (input_line chan)
  with End_of_file ->
    None

(* tail-recursive *)
let rec maplines f chan =
  let rec maplines' f chan acc =
    match getline chan with
      | Some line -> maplines' f chan ((f line)::acc)
      | None      -> List.rev acc
  in maplines' f chan []

(* tail-recursive *)
let rec iterlines f chan =
  match getline chan with
    | Some line -> f line; iterlines f chan
    | None      -> ()

(* transpose a list of lists *)
(* tail-recursive *)
let transpose ll =
  let rec transpose' acc = function
    | [] -> acc
    | []::_ -> acc
    | m -> transpose' ((List.map List.hd m)::acc) (List.map List.tl m)
  in
    List.rev (transpose' [] ll)

(* NOT tail-recursive *)
(*
 * let rec join c str =
 *     match str with
 *       []           -> ""
 *     | [x]          -> x
 *     | (x1::x2::xs) -> x1 ^ c ^ join c (x2::xs)
 *)

(* convert a string list into a string by separating elements with string c *)
(* HOLY CRAP!  String.concat already does this!! *)
(* tail-recursive *)
let join str list =
  let rec join' acc str = function
    | []           -> acc
    | [x]          -> acc ^ str ^ x
    | (x1::x2::xs) -> join' (acc ^ str ^ x1) str (x2::xs)
  in
  let result = (join' "" str list) in
    if result = ""
    then ""
    else String.sub result (String.length str) (String.length result - (String.length str))

module Cset = Set.Make(struct type t = char let compare = compare end)

let split ?(tr=true) ?(merge=false) cs str =
  let rec split1 cs str =
    let len = String.length str in
    let chars = explode cs in
    let cset = List.fold_left (fun a b -> Cset.add b a) Cset.empty (explode " \t\n") in
    let index c = try String.index str c with Not_found -> -1 in
    let indices = List.sort compare (List.filter (fun i -> i > -1) (List.map index chars)) in
    let rec findlast n =
      if n+1 < len then
	if Cset.mem str.[n+1] cset then
	  findlast (n+1)
	else n
      else n
    in
      if indices = []
      then false, str, ""
      else
	let first = List.hd indices in
	let last = if merge then findlast first else first in
	  true, String.sub str 0 first, String.sub str (last+1) (len - (last+1))
  and split'ntr cs str =		(* NOT tail-recursive *)
    match split1 cs str with
      | true,first,rest -> first::(split'ntr cs rest)
      | false,only,_    -> [only]
  and split'tr cs str =			(* tail-recursive *)
    let rec split' cs str acc =
      match split1 cs str with
	| true,first,rest -> split' cs rest (first::acc)
	| false,only,_    -> only::acc
    in
      List.rev (split' cs str [])
  in
    (if tr then split'tr else split'ntr) cs str

(* 10 times faster than: implode (dropwhile ((=) cs) (explode str)) *)
(* not recursive *)
let rec trimleft cs str =
  if str = "" then
    ""
  else
    let i = ref 0 in
    let n = ref (String.length str) in
      while str.[!i] = cs do
	i := !i + 1;
	n := !n - 1;
      done;
      let result = String.create !n in
	String.blit str !i result 0 !n;
	result

(* 30 times as fast as: implode (List.rev (dropwhile ((=) cs) (List.rev (explode str)))) *)
(* not recursive *)
let rec trimright cs str =
  if str = "" then
    ""
  else
    let i = ref ((String.length str) - 1) in
    let n = ref (String.length str) in
      while str.[!i] = cs do
	i := !i - 1;
	n := !n - 1;
      done;
      let result = String.create !n in
	String.blit str 0 result 0 (!i+1);
	result

(* return last element of list; more efficient than nth when you don't
   know the length of the list *)
(* tail-recursive *)
let rec last = function
  |    [] -> raise (Failure "last")
  |   [x] -> x
  | x::xs -> last xs
      
(* not recursive *)
let basename file =
  let comps = split "/" file in
    last comps
