<!--
This README.md file is designed to be tested using `cram`.  The four-space
indented codeblocks serve as tests for the makefile snippets.

First, the makefile snippets need to be scraped to build the Makefile used in
the tests.

    $ make -f $TESTDIR/Makefile README.makefile
    * (glob)
    $ mv README.makefile Makefile

The process running the tests should be given paths to GNU Make versions 3 and 4

    $ alias make-v3=$make_v3
    $ make-v3 -v | head -n 1
    GNU Make 3.* (glob)

    $ alias make-v4=$make_v4
    $ make-v4 -v | head -n 1
    GNU Make 4.* (glob)

-->

If you haven't used `make` much, you may not know that `make` allows you to
specify the shell used to run recipes.  This feature can be used to implement
some interesting behaviour.

# Contents

There are three main sections:

1. Specifying a custom `SHELL`
2. Writing recipes in non-shell programming languages
3. Using a single shell for an entire recipe

There's also an appendix detailing various Makefile features some readers
might not be familiar with:

<ol type="A">
<li>What's a recipe?</li>
<li>What's a target?</li>
<li>What's a rule?</li>
<li>What does <code>.PHONY</code> do?</li>
<li>Why are you using double dollar signs (<code>$$</code>)?</li>
<li>Why did you start listing targets twice?</li>
<li>What does <code>define</code> do?</li>
<li>What does <code>$@</code> mean?</li>
<li>What does <code>.INTERMEDIATE</code> do?</li>
<li>What does <code>.SILENT</code> do?</li>
</ol>


# 1. Specifying a custom `SHELL`

By default, `make` runs each step of a recipe in `/bin/sh`

```makefile
.PHONY: print-shell-name
print-shell-name:
	echo $$0
```

    $ make print-shell-name
    echo $0
    /bin/sh

The shell `make` uses can be changed by setting the `SHELL` Makefile variable,
either globally, per-rule, or at the command line:

```makefile
.PHONY: use-bash
use-bash: SHELL=/bin/bash
use-bash: print-shell-name
```

    $ make use-bash
    echo $0
    /bin/bash
    $ make print-shell-name SHELL=/bin/zsh
    echo $0
    /bin/zsh

The value of `SHELL` doesn't have to be a path to an executable file, though.
It can contain an arbitrary `sh` command.  The only requirement is that the
command can be run with `-c` and the current recipe step.

For example, we could use the shell's `printf` command to inspect our arguments:

    $ make print-shell-name SHELL='printf arg\ =\ %s\\n'
    echo $0
    arg = -c
    arg = echo $0

## Digression: chaining multiple commands
To do anything much more complex than that, we need to have a `SHELL`
that contains multiple shell commands chained together.

In `make` v3 this is trivial, the `SHELL` can contain multiple commands
chained together with `;` as long as it *ends* in something that can accept the
`-c` and the recipe step.  We can run other `sh` commands first and then tack on
a call to `/bin/sh`.

```makefile
.PHONY: greeting
greeting:
	echo hi
```

    $ make-v3 greeting SHELL='echo "--before--";/bin/sh'
    echo hi
    --before--
    hi

This changed in `make` v4, which behaves differently when `SHELL` is defined as
a semicolon-separated chain; instead, everything is passed as an argument to the
first command:

    $ make-v4 greeting SHELL='echo "--before--";/bin/sh'
    echo hi
    "--before--";/bin/sh -c echo hi

The differences between the two versions are similar to the differences betweeen
using `eval` and `exec`:

    $ eval 'echo "--before--";/bin/sh -c echo\ hi'
    --before--
    hi
    $ /bin/sh -c 'exec $@' /bin/sh 'echo "--before--";/bin/sh -c echo hi'
    "--before--";/bin/sh -c echo hi

However, it's still possible to define a `SHELL` for `make` v4 that contains a
multi-command chain by escaping it and wrapping it in another call to `/bin/sh`.

    $ make-v4 greeting SHELL='/bin/sh -c echo\ "--before--";/bin/sh\ "$$@" /bin/sh'
    echo hi
    --before--
    hi

If you're going to be changing the `SHELL` value per-recipe and you want to be
compatible with v3 and v4, this escaping can be centralized by defining `SHELL`
lazily in terms of another makefile variable that contains the unescaped
definition. Here we arbitrarily name that variable `CUSTOM`.

```makefile
CUSTOM = /bin/sh
export CUSTOM

ifeq (3, $(firstword $(subst ., ,$(MAKE_VERSION))))
	SHELL = $(CUSTOM)
else
	SHELL=/bin/sh -c eval\ "f(){\ $$CUSTOM\ "'"$$@"'";\ }";\ f\ "$$@" /bin/sh
endif
```

We'll be using `CUSTOM` for the rest of the article, but it's worth remembering
that `CUSTOM` isn't a special Makefile variable, it's merely used in our
definition of `SHELL`.

---

Now that we know how to chain multiple commands, we can tell `make` to run a
command before each recipe step:

```makefile
.PHONY: before-each-step
before-each-step: CUSTOM=echo '---before---';/bin/sh
before-each-step:
	echo one
	echo two
	echo three
```

    $ make before-each-step
    echo one
    ---before---
    one
    echo two
    ---before---
    two
    echo three
    ---before---
    three

It's a little awkward trying to fit long commands into a one-liner next to
the rule's SHELL definition, so we'll start using `make`'s `define` syntax
for multi-line variable assignments.

```makefile
define BEFORE-EACH-STEP
echo '---before---';
/bin/sh
endef

.PHONY: before-with-define
before-with-define: CUSTOM=$(BEFORE-EACH-STEP)
before-with-define:
	echo one
	echo two
	echo three
```

    $ make before-with-define
    echo one
    ---before---
    one
    echo two
    ---before---
    two
    echo three
    ---before---
    three

`define`-blocks are pretty nice, but there's a fairly important gotcha. in
`make` v3 newlines don't terminate commands as they would in a shell script when
the script is invoked as SHELL, so there's a couple of things to look out for:

- you have to terminate each command with a semicolon since all the lines are
  effectively strung together

  ```makefile
  define MISSING-SEMICOLON
  echo '--before--'
  /bin/sh
  endef

  .PHONY: missing-semicolon
  missing-semicolon: CUSTOM=$(MISSING-SEMICOLON)
  missing-semicolon:
  	echo ok
  ```

  ```
    $ make-v3 missing-semicolon
    echo ok
    --before--
    /bin/sh -c echo ok
  ```

  This is no longer a problem in `make` v4:

  ```
    $ make-v4 missing-semicolon
    echo ok
    --before--
    ok
  ```

- you can't use an octothorpe (`#`) to create comments in the `define`-block as
  it will cause all the following lines to be commented out

  ```makefile
  define WITH-OCTOTHORPE
  echo '--before--';
  # and now we call the shell;
  /bin/sh
  endef

  .PHONY: with-octothorpe
  with-octothorpe: CUSTOM=$(WITH-OCTOTHORPE)
  with-octothorpe:
  	echo ok
  ```

  ```
    $ make-v3 with-octothorpe
    echo ok
    --before--
  ```

  Again, this is not a problem in `make` v4:

  ```
    $ make-v4 with-octothorpe
    echo ok
    --before--
    ok
  ```

But with those restrictions in mind, we can still do some pretty interesting
things before invoking the shell.

For example, we could use the shell's `trap` command to run code when the shell
exits, in effect setting up code to be called *after* each step of the recipe:

```makefile
define AFTER-EACH-STEP
trap 'echo ---after---' EXIT;
/bin/sh
endef

.PHONY: after-each-STEP
after-each-step: CUSTOM=$(AFTER-EACH-STEP)
after-each-step:
	echo one
	echo two
	echo three
```

    $ make after-each-step
    echo one
    one
    ---after---
    echo two
    two
    ---after---
    echo three
    three
    ---after---

Or we could define a custom function to that would be available for recipe steps
to use:

```makefile
define CUSTOM-FUNCTION
log(){
	echo "<log message='$$@'/>";
};
export -f log;
/bin/sh
endef

.PHONY: with-custom-function
with-custom-function: CUSTOM=$(CUSTOM-FUNCTION)
with-custom-function:
	log she sells sea shells by the sea shore
	log pad kid poured curd pulled cod
```

    $ make with-custom-function
    log she sells sea shells by the sea shore
    <log message='she sells sea shells by the sea shore'/>
    log pad kid poured curd pulled cod
    <log message='pad kid poured curd pulled cod'/>

This whole time we've been passing the `-c` <recipe-step> arguments to as
shell, but shells aren't the only commands that can be called this way.

For example, `/bin/echo` will happily take `-c`:

```makefile
.PHONY: use-echo
use-echo: CUSTOM=/bin/echo
use-echo:
	unique new york
	red leather yellow leather
```

    $ make use-echo
    unique new york
    -c unique new york
    red leather yellow leather
    -c red leather yellow leather

(`echo`'s not particularly exciting)

But what about other commands that either don't take `-c` or don't do what we
want with it?

Pulling a trick out of `git-config`'s book, we could also use the command
specified by `SHELL` to define a shell function and let that function be
called with `-c` and the current recipe step.

For example, we could define a function that just inspects its arguments
and have each recipe step invoked with that as its "shell":

```makefile
define INSPECT
inspect(){
	echo "\$$# = $$#";
	echo "\$$0 = $$0";
	echo "\$$1 = $$1";
	echo "\$$2 = $$2";
};inspect
endef

.PHONY: with-inspect
with-inspect: CUSTOM=$(INSPECT)
with-inspect:
	Peter Piper picked a peck of pickled peppers
	I wish I wore an irish wristwatch
```

    $ make with-inspect
    Peter Piper picked a peck of pickled peppers
    $# = 2
    $0 = /bin/sh
    $1 = -c
    $2 = Peter Piper picked a peck of pickled peppers
    I wish I wore an irish wristwatch
    $# = 2
    $0 = /bin/sh
    $1 = -c
    $2 = I wish I wore an irish wristwatch

As a more practical use-case, this technique could be used to generate a file
without wrapping each line in `echo "…" >>target`:

```makefile
define APPEND-TO-TARGET
w(){
	echo "$$2" >>$@;
};w
endef

.PHONY: file-demo
file-demo: cheese-list.txt
	cat cheese-list.txt

.INTERMEDIATE: cheese-list.txt
.SILENT: cheese-list.txt
cheese-list.txt: CUSTOM=$(APPEND-TO-TARGET)
cheese-list.txt:
	· cheddar
	· edam
	· mozzerella
	· queso fresco
	· brie
```

    $ make file-demo
    cat cheese-list.txt
    · cheddar
    · edam
    · mozzerella
    · queso fresco
    · brie
    rm cheese-list.txt

# 2. Writing recipes in non-shell programming languages

This technique of defining a function and letting it be called with the
SHELL's arguments is extremely powerful as it lets us arbitrarily manipulate
those arguments, pass them to whatever commands we want, and manipulate those
commands' output.

For example, we could interpret the recipe steps in a non-shell programming
language, like ruby.

Here we pass the recipe step to ruby, asking it to evaluate the step and
print its resulting value.

```makefile
define RUBY
r(){
	ruby -e "p ($$2)" | sed 's/^/# /';
}; r
endef

.PHONY: in-ruby
in-ruby: CUSTOM=$(RUBY)
in-ruby:
	puts "hello ruby!"
	Struct.new(:a,:b).new(1,2)
```

    $ make in-ruby
    puts "hello ruby!"
    # hello ruby!
    # nil
    Struct.new(:a,:b).new(1,2)
    # #<struct a=1, b=2>

Or we could use haskell with its repl, `ghci`. The haskell compiler is less
commonly installed than ruby, so we better test for that:

```makefile
define GHCI
g(){
	if command -v ghci >/dev/null; then
		exec ghci -e "$$2" | sed 's/^/-- /';
	else
		echo "-- ghci is not installed";
	fi;
}; g
endef

.PHONY: in-haskell
in-haskell: CUSTOM=$(GHCI)
in-haskell:
	putStrLn "hello haskell!"
	let fibs = 1 : 1 : zipWith (+) fibs (tail fibs) in take 10 fibs
```

    $ make in-haskell
    putStrLn "hello haskell!"
    -- hello haskell!
    let fibs = 1 : 1 : zipWith (+) fibs (tail fibs) in take 10 fibs
    -- [1,1,2,3,5,8,13,21,34,55]

Neither of those is as popular as python, so let's give that a whilr,
with some useful imports for file manipulation:

```makefile
define PYTHON
p(){
	exec python3 -c "import pathlib,os,shutil,sys;print(repr($$2))" | sed 's/^/# /';
}; p
endef

.PHONY: in-python
in-python: CUSTOM=$(PYTHON)
in-python:
	print("hello from python!")
	pathlib.Path('a-file').touch()
	os.mkdir('a-dir')
	shutil.move('a-file','a-dir')
	os.listdir('a-dir')
	shutil.rmtree('a-dir')
```

    $ make in-python
    print("hello from python!")
    # hello from python!
    # None
    pathlib.Path('a-file').touch()
    # None
    os.mkdir('a-dir')
    # None
    shutil.move('a-file','a-dir')
    # 'a-dir/a-file'
    os.listdir('a-dir')
    # ['a-file']
    shutil.rmtree('a-dir')
    # None

# 3. Using a single shell for an entire recipe

One of the things that surprises many people new to `make` is that the shell
used in recipes is non-persistent; that is, a new shell is invoked for each
step of the recipe.

```makefile
.PHONY: non-persistent
non-persistent:
	x=1
	y=2
	echo $${x:-unset}
	echo $${y:-unset}
```

    $ make non-persistent
    x=1
    y=2
    echo ${x:-unset}
    unset
    echo ${y:-unset}
    unset

In the above example, `x` and `y` are unset because the shells that set x and
y have both closed, taking their settings with them.

GNU Make version 4 introduced [the `.ONESHELL` special target](https://www.gnu.org/software/make/manual/html_node/One-Shell.html), which tells `make` to pass all the steps of each recipe to a single shell to be run together:

<!--
    $ cp $TESTDIR/oneshell.makefile .
-->
    $ cat oneshell.makefile
    .ONESHELL:
    
    default:
    	x=1
    	y=2
    	echo $${x:-unset}
    	echo $${y:-unset}
    
    $ make-v4 -f oneshell.makefile
    x=1
    y=2
    echo ${x:-unset}
    echo ${y:-unset}
    1
    2

`.ONESHELL` is very easy to use, but it has some drawbacks.

- It's a bit of a blunt instrument, as you can't use `.ONESHELL` to specify
  that a single recipe should be run in a persistent shell, only to tell
  `make` to use that strategy for *all* the recipes in a file

- It only works in GNU Make v4 and above, and will fall back silently
  to a non-persistent shell in v3:

  ```
    $ make-v3 -f oneshell.makefile
    x=1
    y=2
    echo ${x:-unset}
    unset
    echo ${y:-unset}
    unset
  ```

- The echoed commands and their output are no longer interspersed, so it's a
  little harder to see what command emits what.

To take another approach, a trailing backslash joins multiple lines in a recipe
into a single step:

```makefile
.PHONY: trailing-backslash-example
trailing-backslash-example:
	echo \
	one \
	t\
	w\
	o\
	 \
	three
```

    $ make-v3 trailing-backslash-example
    echo \
    	one \
    	t\
    	w\
    	o\
    	 \
    	three
    one two three

One slight difference between v3 and v4 is whether the leading tabs on the later
lines is shown when the command is echoed:

    $ make-v4 trailing-backslash-example
    echo \
    one \
    t\
    w\
    o\
     \
    three
    one two three

We can combine this with `/bin/sh`'s `;` operator for chaining multiple commands into
a single line to get a recipe that runs in a single shell.

```makefile
.PHONY: multi-line
multi-line:
	x=1;\
	y=2;\
	echo $${x:-unset};\
	echo $${y:-unset}
```

    $ make-v3 multi-line
    x=1;\
    	y=2;\
    	echo ${x:-unset};\
    	echo ${y:-unset}
    1
    2

This approach is less global and version 3 compliant than `.ONESHELL`, but it's a bit
noisy.


More complex stateful operations that require a persistent shell should
probably become their own shell script. Many shells can be told to print
commands before running them using '-v'

```makefile
.PHONY: shell-script
shell-script: script.sh
	/bin/sh -v $<

.INTERMEDIATE: script.sh
.SILENT: script.sh
script.sh: CUSTOM=$(APPEND-TO-TARGET)
script.sh:
	x=1
	y=2
	echo $${x:-unset}
	echo $${y:-unset}
```

    $ make shell-script
    /bin/sh -v script.sh
    x=1
    y=2
    echo ${x:-unset}
    1
    echo ${y:-unset}
    2
    rm script.sh



As with any technique, custom SHELLs can be misused, but if used correctly
they provide an opportunity to remove unnecessary repetition from your
Makefile and make it easier to focus on what's important.

# APPENDIX

A. What's a recipe?
===================

B. What's a target?
===================

C. What's a rule?
===================

Here's how the make manual defines rule, recipe, and target:

> A simple makefile consists of /rules/ with the following shape:
>
>   target … : prerequisites …
>   	recipe
>   	…
>   	…
>
> A /target/ is usually the name of a file that is generated by a program;
> examples of targets are executables or object files. A target can also be
> the name of an action to carry out, such as 'clean' (see Phony Targets).
>
> A /prerequisite/ is a file that is used as input to create the target. A
> target often depends on several files.
>
> A /recipe/ is an action that `make` carries out. A recipe may have more than
> one command, either on the same line or each on its own line. **Please
> note:** you need to put a tab character at the beginning of every recipe
> line! This is an obscurity that catches the unwary. […]

(https://www.gnu.org/software/make/manual/make.html#What-a-Rule-Looks-Like)

D. What does `.PHONY` do?
==============================

By default, `make` assumes its targets are actual files. If a file with the
same name as the target exists and is newer than all its prerequisites, `make`
won't bother to run its rule, assuming the file is already up-to-date.

> A phony target is one that is not really the name of a file; rather it is
> just a name for a recipe to be executed when you make an explicit request.
> There are two reasons to use a phony target; to avoid a conflict with a file
> of the same name, and to improve performance.
>
> […]
>
> [Y]ou can explicitly declare the target to be phony by making it a
> prerequisite of the special target `.PHONY` (see Special Built-in Target
> Names) as follows:
>
> ```
> .PHONY: clean
> clean:
> 	rm *.o temp
> ```
>
> Once this is done, `make clean` will run the recipe regardless of whether
> there is a file named `clean`.

(https://www.gnu.org/software/make/manual/html_node/Phony-Targets.html)

While declaring targets `.PHONY` isn't strictly necessary, I stick to it here
as I consider it good style.

E. Why are you using double dollar signs everywhere (`$$`)?
===========================================================

`$` is used by `make` to introduce its variables and function calls, so to use
`$` in a recipe step it must be escaped. `make` expands `$$` to just `$`
before evaluating recipe steps.

For more details, see the make manual:
(https://www.gnu.org/software/make/manual/html_node/Reference.html)

F. Why did you start listing targets twice?
===========================================

In the rule definition:

```make
use-bash: SHELL=/bin/bash
use-bash:
```

I'm using `make`'s syntax for target-specific variable assignments. The
variable assignments need to go on a separate line than the prerequisites
(even if a target has no prerequisites):

> Variable values in `make` are usually global; that is, they are the same
> regardless of where they are evaluated (unless they're reset, of course). One
> exception to that is automatic variables (see Automatic Variables).
>
> The other exception is /target-specific variable values/. This feature
> allows you to define different values for the same variable, based on the
> target `make` is currently building. As with automatic variables, these
> values are only available within the context of a target's recipe (and in
> other target-specific assignments).

(https://www.gnu.org/software/make/manual/html_node/Target_002dspecific.html)

G. What does `define` do?
==============================

`define` is `make`'s syntax for defining a multi-line variable:

> Another way to set the value of a variable is to use the `define` directive.
> This directive has an unusual syntax which allows newline characters to be
> included in the value, which is convenient for defining both canned
> sequences of commands (see Defining Canned Recipes), and also sections of
> makefile syntax to use with eval (see Eval Function).
>
> The `define` directive is followed on the same line by the name of the
> variable being defined and an (optional) assignment operator, and nothing
> more. The value to give the variable appears on the following lines. The end
> of the value is makred by a line containing just the word `endef`.

(https://www.gnu.org/software/make/manual/html_node/Multi_002dLine.html)

H. What does `$@` mean?
==========================

`$@` is one of `make`'s automatic variables, set locally for each rule. It
resolves to the filename matched by the target.

Most often, this is simply used to avoid repeating the target name inside the
rule (especially useful if you decide to change the name of the target later).

However, since variables defined by `=` in the Makefile are lazily evaluated,
this makes it possible to have global variables (like APPEND-TO-TARGET) refer
to the current target's name:

  define APPEND-TO-TARGET
  w(){
  	echo "$$2" >>$@;
  };w
  endef

/bin/sh and other shells also have a variable named `$@` (escaped in the
Makefile as `$$@`) which is an array of all the arguments to a shell function.

For more on `make`'s automatic variables, see the make manual
(https://www.gnu.org/software/make/manual/html_node/Automatic-Variables.html).

For more more on the lazy evaluation of `make` variables see the description
of /recursively expanded/ variables in the make manual
(https://www.gnu.org/software/make/manual/html_node/Flavors.html).

For more on the shell variable `$@` see the description of `@` under "Special
Parameters" in `man bash`.

I. What does `.INTERMEDIATE` do?
=====================================

Sometimes it's necessary to generate /intermediate/ files as a step between
your input files and your ultimate product. These intermediate files serve no
purpose in-and-of themselves and can litter your source directory if not
cleaned up.

For example, if I compile several .c source files into .o object files, then
combine all the .o files into a single .a archive file, I have no use for the
.o files once I have the .a file. They're just cluttering my build directory
and can be deleted.

Make can sometimes autodetect such intermediate files, but normally listing a
file as a target or prerequisite prevents such detection.  Adding the file as
a prerequisite of `.INTERMEDIATE` is how `make` can be explicitly told to
delete a file if it's generated as part of a chain.

I tagged the `APPEND-TO-FILE` file targets as `.INTERMEDIATE` as the only real
purpose of those files is to be used in the examples and tests, and won't be
needed after `make` completes.

For more on intermediate files, I recommend reading the "Chains of Implicit
Rules" section of the make manual
(https://www.gnu.org/software/make/manual/html_node/Chained-Rules.html).

J. What does `.SILENT` do?
===============================

By default, `make` prints each recipe step before it is executed.

> If you specify prerequisites for `.SILENT`, then `make` will not print the
> recipe used to remake those particular files before executing them.

- ["Special Targets"](https://www.gnu.org/software/make/manual/html_node/Special-Targets.html)

More commonly, you'll see people silencing single steps of a recipe by
prefixing the step with `@` or running `make --silent` to silence all recipes.

I tagged the `APPEND-TO-TARGET` rules as `.SILENT` so that the echoing of the
recipe steps during file generation wouldn't be mistaken for the echoing
during the rules that depend on those files.

----

With some work, we can come up with a custom SHELL function that persists a
shell between recipe steps and addresses those three issues:

```makefile
define PERSIST
: Using octothorpe for comments is not make-v3 compatible, but we can fake     ;
: comments using ':', the no-op command, as long as the comment does not use   ;
: any shell syntax that would break it.                                        ;

: Path for the named pipe used to pass a stream of recipe steps to a           ;
: backgrounded persistent shell                                                ;
entire_recipe=.$@-entire_recipe.fifo;

: Path for the named pipe used to indicate when a single recipe step has       ;
: finished running                                                             ;
recipe_step_complete=.$@-recipe_step_complete.fifo;

start_background_shell_if_necessary(){
	: Since the background process deletes the pipes when the shell is complete, ;
	: assume that the background shell is running if and only if the pipes exist ;

	if ! [[ -p $$entire_recipe && -p $$recipe_step_complete ]]; then
		mkfifo $$entire_recipe $$recipe_step_complete;

		: In a backgrounded process, run the entire recipe in a subshell and then  ;
		: clean up the pipes                                                       ;
		{
			/bin/sh $$entire_recipe;
			rm -f $$entire_recipe $$recipe_step_complete;
		} &
	fi;
};

run_recipe_step(){
	: Write the output of all the following commands to the recipe pipe for the  ;
	: backgrounded shell.                                                        ;

	: As long as at least one process has a writable file handle for the recipe  ;
	: pipe open, EOF will not be written to the pipe and the backgrounded shell  ;
	: will continue trying to run commands from it.                              ;

	: If instead commands wrote to the recipe pipe individually, then EOF would  ;
	: be written to the pipe at the end of each command, allowing the            ;
	: backgrounded                                                               ;
	: shell to reach the "end" of the pipe and move on to cleanup prematurely.   ;

	exec >$$entire_recipe;

	recipe_step=$$2;
	echo "$$recipe_step";

	: Use the output pipe as a synchronization lock to detect when the           ;
	: backgrounded shell has finished running this recipe step. Otherwise, if we ;
	: did not wait, the output of one step might print after make echoes the next;
	: recipe step                                                                ;
	echo "true > $$recipe_step_complete";
	cat $$recipe_step_complete >/dev/null;

	: Use "sleep" to keep the recipe file handle open in the background          ;
	: for long enough for make to call run_recipe_step again with the next       ;
	: recipe step, preventing the background shell from ending between recipe    ;
	: steps                                                                      ;
	sleep .1 &
};

start_background_shell_if_necessary;
run_recipe_step
endef

.PHONY: persistent
persistent: CUSTOM=$(PERSIST)
persistent:
	x=1
	y=2
	echo $${x:-unset}
	echo $${y:-unset}
```

    $ make persistent
    x=1
    y=2
    echo ${x:-unset}
    1
    echo ${y:-unset}
    2

It is not a trivial chunk of scripting, but it can be done!

But should it be used? No, probably not.

For one, it's not completely functional; it doesn't connect STDIN to the STDIN
of the backgrounded shell, so it'll work differently than a non-persistent
shell there.

```makefile
.PHONY: using-stdin
using-stdin: CUSTOM=$(PERSIST)
using-stdin:
	tr a-z A-Z
```

    $ echo "hello" | make using-stdin
    tr a-z A-Z
    $ echo "hello" | make SHELL=/bin/sh using-stdin
    tr a-z A-Z
    HELLO

