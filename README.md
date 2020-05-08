# OCaml Shell Scripts? 

## Sources [https://www2.lib.uchicago.edu/keith/ocaml-class/complete.html](https://www2.lib.uchicago.edu/keith/ocaml-class/complete.html)

## A Couple of OCaml Programs

Before we get started, let's just see what a couple of complete, real-world OCaml programs look like.

### First Example: cat

The first program is just an OCaml version of the Unix cat command.

```re
let cat filename =
  let chan = open_in filename in
  let size = 4 * 1024 in
  let buffer = String.create size in
  let eof = ref false in
    while not !eof do
      let len = input chan buffer 0 size in
	if len > 0
	then print_string (String.sub buffer 0 len)
	else eof := true
    done

let main () =
  let len = (Array.length Sys.argv) in
  let argv = (Array.sub Sys.argv 1 (len-1)) in (* skip argv0 *)
    Array.iter cat argv

let _ = main ()
```

This code is explained elsewhere ([cat function](./docs/ControlStructure), [main function](./docs/ControlStructure)). For now, just note that the program is just a sequence of let-definitions, ending with an invocation of the main function (ignoring its return value).

The simplest way to run this program, but the least commonly used, is to invoke:

```zsh
    $ ocaml lib/cat.ml ../package.json  

~/Downloads/oml master*
❯ ocaml lib/cat.ml package.json 
{
  "name": "hello-ocaml",
  "version": "0.1.0",
  "description": "OCaml workflow with Esy",
  "license": "MIT",
  "esy": {
    "build": "dune build -p #{self.name}",
    "release": {
      "bin": "hello",
      "includePackages": [
        "root",
        "@opam/camomile"
      ]
    }
  },
  "scripts": {
    "test": "esy x hello"
  },
  "dependencies": {
    "@opam/dune": "*",
    "@opam/lambda-term": "*",
    "@opam/lwt": "*",
    "ocaml": "~4.8.1"
  },
  "devDependencies": {
    "@opam/merlin": "*",
    "ocaml": "~4.8.1"
  }
}
    $
```

In other words, just run your program under the ocaml interpreter. This is the slowest approach, since you will be parsing and compiling byte-code with every invocation (which is the norm with many interpreted languages, like Tcl and Perl). The normal thing is to compile and link this program into an executable ahead of time, in this case with this command:

```sh
    $ ocamlc -o cat lib/cat.ml   
    $ ./cat package.json 
    {
    "name": "hello-ocaml",
    "version": "0.1.0",
    "description": "OCaml workflow with Esy",
    "license": "MIT",
    ...
    }
```

### Second Example: ocolumn

The second program, called ocolumn, is a version of FreeBSD's column(1) program that doesn't dump core on long lines. It's a more realistic example.

This program is written in two source files; note that OCaml source code files use the extension .ml:

ocolumn.ml
This is the main program.
utils.ml
This is a separate module of utility functions that I thought would be generally useful in other programs.
Note also that it uses a third-party regular-expression module called Pcre.

Using the very handy OCamlMakefile from Markus Mottl and this Makefile:

    SOURCES = utils.ml ocolumn.ml
    PACKS = pcre
    RESULT  = ocolumn

    -include OCamlMakefile
      
I can compile and link this program just by saying gmake. See Compiling and Running Programs for more details.

This page was last updated on 17 June 2006.

