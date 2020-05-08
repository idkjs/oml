# OCaml for the Skeptical 

## Control Structures

In a functional language, not many control structures are needed; functions can do almost everything. The only control structure that's really necessary is a conditional expression (and even that's not necessary in a lazy language[1]).

But OCaml, as an impure functional language, also provides control structures for iteration, and pattern matching combines a multi-armed conditional, unification, data destructuring and variable binding into one powerful control structure.

### Conditional Expression

OCaml's conditional expression is if expr then expr else expr. There's nothing special to say about it, as long as you remember that you use parentheses around any expr only if necessary to disambiguate, and that the entire conditional is itself an expression (which of course may sometimes require parens around the entire conditional). Layout is completely up to you; here are three of the possibilities:

```ocaml
if b <> 0 then a / b else 1
if b <> 0 then
  a / b
else
  1
if b <> 0
then a / b
else 1
While Loop and For Loop
```

Most OCaml programmers do a lot of their loops via recursive functions. However, there are two imperative loops: a conventional while loop, and a counting for loop like that of Algol 60.

### For Loop

The for loop is the easiest to use, since it's more structured and thus can hide some of its imperativeness. It's a typical counting loop that takes one of the following two forms:

```ocaml
    for name = expr1 to expr2 do expr3 done
    for name = expr1 downto expr2 do expr3 done
```
The name is bound, in the loop body expr3, to the integer values between expr1 and expr2 inclusive, either increasing (to) or decreasing (downto). So expr3 is executed repeatedly, which will only be useful if it contains a side-effect (e.g. I/O or the modification of a mutable data structure like a ref, record, array or string). The entire for loop is an expression, but it's value is always () (the unit value).

Here's a trivial example that uses I/O as the side-effect:
```ocaml
    # for i = 1 to 4 do print_endline (string_of_int i) done;;
    1
    2
    3
    4
    - : unit = ()
    #
```

string_of_int converts an int to a string, and print_endline prints a string to standard output, terminating it with a newline.

Here's an example modifying a ref in the loop body to implement an iterative factorial:

```ocaml
    # let fac n =
	let result = ref 1 in
	  for i = 2 to n do
	    result := !result * i
	  done;
	!result
      ;;
    val fac : int -> int = <fun>
    # fac 6;;
    - : int = 720
    #
```
Note the let that establishes a ref as an accumulator. It's important that this let be wrapped around the for so that each iteration modifies the same reference! Similarly, you can't use a lambda variable (i.e. function parameter or let binding) to accomplish this:

```ocaml
    # let fac n = (* bogus! *)
	let result = 1 in
	  for i = 2 to n do
	    let result = result * i in ()
	  done;
	  result
	;;
    val fac : int -> int = <fun>
    # fac 6;;
    - : int = 1
    #
```
This fails because, as we've seen before, the outer and inner bindings of result are completely unrelated variables, and also because the inner result is only bound in the inner let body (which is () for reasons of type consistency). As each iteration finishes, the inner let body is exited and the local binding of result is thrown away. The result of the function will be 1 for any value of n.

### While Loop

The while loop is much like that of C or most any imperative language. The syntax is:

```ocaml
    while expr1 do expr2 done
```
Here's an implementation of the Unix cat command, i.e. a function that takes a filename and copies the contents of that file to standard output; the input function, a (mutable) string buffer, and a loop-controlling reference (eof) provide the needed side-effects:

```ocaml
    # let cat filename =
      let chan = open_in filename in
      let size = 4 * 1024 in
      let buffer = String.create size in
      let eof = ref false in
	while not !eof do
	  let len = input chan buffer 0 size in
	    if len > 0
	    then print_string (String.sub buffer 0 len)
	    else eof := true
	done;;
      val cat : string -> unit = <fun>
    # cat "/etc/motd";;
    FreeBSD 4.6.2-RELEASE-p14 (JFCL) #2: Fri Oct  3 17:01:27 CDT 2003

    jfcl: The University of Chicago Library: Thu Apr  1 15:54:06 CST 2004

    This is jinn via ssh.
    - : unit = ()
    #
```

This function is written almost exactly the way you'd do it in C. There are several points to note:

A while loop is an expression which always returns () (the unit value) and so the return value of cat is ().
The function we use to open the input file, open_in, is distinct from the function we would use to open an output file, open_out. This allows OCaml to have two different types for opened files, called channels: the type of input channels, in_channel, and the type of output channels: out_channel. This allows the type checker to detect any mixups between input files and output files at compile time!
We use a Boolean reference (eof) to control the termination of the loop.
We read 4K chunks of input at a time with input (the most generic input function in the Standard Library), which takes as parameters an input channel, a string in which to store the data that's read from that channel, and an offset and length within that string at which to store it.

Remember that strings are mutable data structures, which is why the input function can store data into its parameter!
String.sub returns a substring of its string argument from the given offset and of the given length.
Footnotes

A conditional isn't theoretically necessary even in an eager language, but the technique that replaces it is too tedious for ordinary use.
This page was last updated on 17 June 2006.