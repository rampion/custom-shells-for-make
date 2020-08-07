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

1. [Specifying a custom `SHELL`](#1-specifying-a-custom-shell)
2. [Writing recipes in non-shell programming languages](#2-writing-recipes-in-non-shell-programming-languages)
3. [Using a single shell for an entire recipe](#3-using-a-single-shell-for-an-entire-recipe)

There's also an appendix detailing various Makefile features some readers
might not be familiar with:

<ol type="A">
<li><a href="#a-whats-a-recipe">What's a recipe?</a></li>
<li><a href="#b-whats-a-target">What's a target?</a></li>
<li><a href="#c-whats-a-rule">What's a rule?</a></li>
<li><a href="#d-what-does-phony-do">What does <code>.PHONY</code> do?</a></li>
<li><a href="#e-why-are-you-using-double-dollar-signs-everywhere-">Why are you using double dollar signs (<code>$$</code>)?</a></li>
<li><a href="#f-why-did-you-start-listing-targets-twice">Why did you start listing targets twice?</a></li>
<li><a href="#g-how-does-the-shell-work-differently-in-different-versions">How does the <code>SHELL</code> work differently in different versions?</a></li>
<li><a href="#h-what-does-it-mean-to-define-a-makefile-variable-lazily">What does it mean
to define a makefile variable lazily?</a></li>
<li><a href="#i-what-does-define-do">What does <code>define</code> do?</a></li>
<li><a href="#j-what-does--mean">What does <code>$@</code> mean?</a></li>
<li><a href="#k-what-does-intermediate-do">What does <code>.INTERMEDIATE</code> do?</a></li>
<li><a href="#l-what-does-silent-do">What does <code>.SILENT</code> do?</a></li>
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

For example, we could use the builtin `printf` command to inspect the arguments
`SHELL` is called with:

    $ make print-shell-name SHELL='printf arg\ =\ %s\\n'
    echo $0
    arg = -c
    arg = echo $0

[The `SHELL` works slightly differently in different versions of `make`](#g-how-does-the-shell-work-differently-in-different-versions), so
to do anything more complicated, it's helpful to define `SHELL` lazily in terms
of another makefile variable.

```makefile
CaCO3 = /bin/sh
export CaCO3

ifeq (3, $(firstword $(subst ., ,$(MAKE_VERSION))))
	# escape so multiline define statements work properly
	SHELL=eval "f(){ $$CaCO3 "'"$$@"'"; }"; f
endif

ifeq (4, $(firstword $(subst ., ,$(MAKE_VERSION))))
	# escape so multiple commands can be chained together
	SHELL=/bin/sh -c eval\ "f(){\ $$CaCO3\ "'"$$@"'";\ }";\ f\ "$$@" /bin/sh
endif
```

Here, we arbitrarily named the variable `SHELL` is built from `CaCO3`, mainly
for the [pun](https://en.wikipedia.org/wiki/CaCO3#Biological_sources).
We'll be using `CaCO3` for the rest of the article, but it's worth remembering
that `CaCO3` isn't a special Makefile variable, it's merely used in our
definition of `SHELL`.

With that in place, we can tell `make` to run a command before each recipe step:

```makefile
.PHONY: before-each-step
before-each-step: CaCO3=echo '---before---';/bin/sh
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
the rule's `SHELL` definition, so we'll start using `make`'s `define` syntax
for multi-line variable assignments.

```makefile
define BEFORE-EACH-STEP
echo '---before---'
/bin/sh
endef

.PHONY: before-with-define
before-with-define: CaCO3=$(BEFORE-EACH-STEP)
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

For example, we could use the shell's `trap` command to run code when the shell
exits, in effect setting up code to be called *after* each step of the recipe:

```makefile
define AFTER-EACH-STEP
trap 'echo ---after---' EXIT
/bin/sh
endef

.PHONY: after-each-step
after-each-step: CaCO3=$(AFTER-EACH-STEP)
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

Or we could define a custom function that would be available for recipe steps
to use:

```makefile
define CUSTOM-FUNCTION
log(){
	echo "<log message='$$@'/>"
}
export -f log
/bin/sh
endef

.PHONY: with-custom-function
with-custom-function: CaCO3=$(CUSTOM-FUNCTION)
with-custom-function:
	log she sells sea shells by the sea shore
	log pad kid poured curd pulled cod
```

    $ make with-custom-function
    log she sells sea shells by the sea shore
    <log message='she sells sea shells by the sea shore'/>
    log pad kid poured curd pulled cod
    <log message='pad kid poured curd pulled cod'/>

This whole time we've been passing the `-c` <recipe-step> arguments to a
shell, but shells aren't the only commands that can be called this way.

For example, `/bin/echo` will happily take `-c`:

```makefile
.PHONY: use-echo
use-echo: CaCO3=/bin/echo
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
specified by `SHELL` to define a shell function and immediately call it.

For example, we could define a function that just inspects its arguments
and have each recipe step invoked with that as its "shell":

```makefile
define INSPECT
inspect(){
	echo "\$$# = $$#"
	echo "\$$0 = $$0"
	echo "\$$1 = $$1"
	echo "\$$2 = $$2"
}
inspect
endef

.PHONY: with-inspect
with-inspect: CaCO3=$(INSPECT)
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
	echo "$$2" >>$@
}
w
endef

.PHONY: file-demo
file-demo: cheese-list.txt
	cat cheese-list.txt

.INTERMEDIATE: cheese-list.txt
.SILENT: cheese-list.txt
cheese-list.txt: CaCO3=$(APPEND-TO-TARGET)
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
`SHELL`'s arguments is extremely powerful as it lets us arbitrarily manipulate
those arguments, pass them to whatever commands we want, and manipulate those
commands' output.

For example, we could interpret the recipe steps in a non-shell programming
language.

Here we pass the recipe steps to ruby, asking it to evaluate the step and
print its resulting value.

```makefile
define RUBY
r(){
	ruby -e "p ($$2)" | sed 's/^/# /'
}
r
endef

.PHONY: in-ruby
in-ruby: CaCO3=$(RUBY)
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
in-haskell: CaCO3=$(GHCI)
in-haskell:
	putStrLn "hello haskell!"
	let fibs = 1 : 1 : zipWith (+) fibs (tail fibs) in take 10 fibs
```

    $ make in-haskell
    putStrLn "hello haskell!"
    -- hello haskell!
    let fibs = 1 : 1 : zipWith (+) fibs (tail fibs) in take 10 fibs
    -- [1,1,2,3,5,8,13,21,34,55]

Neither of those is as popular as python, so let's give that a whirl,
with some useful imports for file manipulation:

```makefile
define PYTHON
p(){
	exec python3 -c "import pathlib,os,shutil,sys;print(repr($$2))" | sed 's/^/# /';
}; p
endef

.PHONY: in-python
in-python: CaCO3=$(PYTHON)
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
  that a single rule should be run in a persistent shell, only to tell
  `make` to use that strategy for *all* the rules in a file

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
commands before running them using `-v`, which seems like a happy medium.

```makefile
.PHONY: using-shell-script
using-shell-script: script.sh
	/bin/sh -v $<

.INTERMEDIATE: script.sh
.SILENT: script.sh
script.sh: CaCO3=$(APPEND-TO-TARGET)
script.sh:
	x=1
	y=2
	echo $${x:-unset}
	echo $${y:-unset}
```

    $ make using-shell-script
    /bin/sh -v script.sh
    x=1
    y=2
    echo ${x:-unset}
    1
    echo ${y:-unset}
    2
    rm script.sh

---

As with any technique, custom `SHELL`s can be misused, but if used correctly
they provide an opportunity to remove unnecessary repetition from your
Makefile and make it easier to focus on what's important.

# APPENDIX

A. What's a recipe?
===================

B. What's a target?
===================

C. What's a rule?
===================

Here's [how the make manual defines rule, recipe, and target](https://www.gnu.org/software/make/manual/make.html#What-a-Rule-Looks-Like):

> A simple makefile consists of *rules* with the following shape:
>
>     target … : prerequisites …
>     	recipe
>     	…
>     	…
>
> A *target* is usually the name of a file that is generated by a program;
> examples of targets are executables or object files. A target can also be
> the name of an action to carry out, such as 'clean' (see Phony Targets).
>
> A *prerequisite* is a file that is used as input to create the target. A
> target often depends on several files.
>
> A *recipe* is an action that `make` carries out. A recipe may have more than
> one command, either on the same line or each on its own line. **Please
> note:** you need to put a tab character at the beginning of every recipe
> line! This is an obscurity that catches the unwary. […]

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
>
>     .PHONY: clean
>     clean:
>     	rm *.o temp
>
>
> Once this is done, `make clean` will run the recipe regardless of whether
> there is a file named `clean`.

(from the [make manual on "Phony Targets"](https://www.gnu.org/software/make/manual/html_node/Phony-Targets.html))

While declaring targets `.PHONY` isn't strictly necessary, I stick to it here
as I consider it good style.

E. Why are you using double dollar signs everywhere (`$$`)?
===========================================================

`$` is used by `make` to introduce its variables and function calls, so to use
`$` in a recipe step it must be escaped. `make` expands `$$` to just `$`
before evaluating recipe steps.

For more details, see [the make manual](https://www.gnu.org/software/make/manual/html_node/Reference.html)

F. Why did you start listing targets twice?
===========================================

In the rule definition:

```make
use-bash: SHELL=/bin/bash
use-bash:
```

I'm using [`make`'s syntax for target-specific variable assignments](https://www.gnu.org/software/make/manual/html_node/Target_002dspecific.html). The
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

G. How does the `SHELL` work differently in different versions?
===============================================================

In `make` version 3, the `SHELL` can contain multiple commands chained together
with `;` as long as it *ends* in something that can accept the `-c` and the
recipe step.  We can run other `sh` commands first and then tack on a call to
`/bin/sh`.

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
multi-command chain by escaping the command chain and wrapping it in another
call to `/bin/sh`.

    $ make-v4 greeting SHELL='/bin/sh -c echo\ "--before--";/bin/sh\ "$$@" /bin/sh'
    echo hi
    --before--
    hi

Defining a make function that will transform a `SHELL` that works for version 3
into one that works for version 4 is a little tricky, since there's 
[no `make` function for escaping shell commands](https://www.gnu.org/software/make/manual/html_node/Functions.html#Functions).

The workaround used in this article is to export the desired command chain as an
environment variable, and use `eval` to transform that into a runnable command:

```make
CaCO3 = /bin/sh
export CaCO3

# ‥.

ifeq (4, $(firstword $(subst ., ,$(MAKE_VERSION))))
	# escape so multiple commands can be chained together
	SHELL=/bin/sh -c eval\ "f(){\ $$CaCO3\ "'"$$@"'";\ }";\ f\ "$$@" /bin/sh
endif
```

    $ make-v4 greeting CaCO3='echo "--before--";/bin/sh'
    echo hi
    --before--
    hi

This workaround does have a case where it handles command-chains differently
than `make` version 3 does, multi-line command chains from `define` blocks:

```makefile
define MISSING-SEMICOLON
echo '--before--'
/bin/sh
endef

define WITH-OCTOTHORPE
printf -- '--be';
# and breathe;
printf 'fore--\n';
/bin/sh
endef
```

`define` blocks make it easy to define a larger command chain to be used as a
`SHELL` command. They look like writing a shellscript, rather than a one-liner.
However, somewhat unintuitively `make` version 3 treats command chains used as a
`SHELL` as if they were defined on a single line.

This means, unlike in a script, commands must be terminated by a semicolon:

    $ make-v3 greeting 'SHELL=$(MISSING-SEMICOLON)'
    echo hi
    --before--
    /bin/sh -c echo hi

And an unquoted `#` anywhere in the script will comment out the remaining lines:

    $ make-v3 greeting 'SHELL=$(WITH-OCTOTHORPE)'
    echo hi
    --be (no-eol)

The effect is similar to that of calling `/bin/sh` with `eval $@` rather than
`eval "$@"`:

    $ SCRIPT=$'echo one\necho two\necho three'
    $ echo "$SCRIPT"
    echo one
    echo two
    echo three
    $ /bin/sh -c 'eval $@' /bin/sh "$SCRIPT"
    one echo two echo three
    $ /bin/sh -c 'eval "$@"' /bin/sh "$SCRIPT"
    one
    two
    three

    $ SCRIPT=$'echo one;\necho two;\n# skip three;\necho four'
    $ echo "$SCRIPT"
    echo one;
    echo two;
    # skip three;
    echo four
    $ /bin/sh -c 'eval $@' /bin/sh "$SCRIPT"
    one
    two
    $ /bin/sh -c 'eval "$@"' /bin/sh "$SCRIPT"
    one
    two
    four
    $ SCRIPT=$'echo one\n# skip two\necho three'

The workaround for command chains for `make` version 4 has neither of these
gotchas:

    $ make-v4 greeting 'CaCO3=$(MISSING-SEMICOLON)'
    echo hi
    --before--
    hi
    $ make-v4 greeting 'CaCO3=$(WITH-OCTOTHORPE)'
    echo hi
    --before--
    hi

So, rather than change the version 4 workaround to have the same surprising
behaviour as `make` version 3, this article reuses the trick of passing the
command chain to `eval` through an environment variable:

```make
ifeq (3, $(firstword $(subst ., ,$(MAKE_VERSION))))
	# escape so multiline define statements work properly
	SHELL=eval "f(){ $$CaCO3 "'"$$@"'"; }"; f
endif
```

    $ make-v3 greeting 'CaCO3=$(MISSING-SEMICOLON)'
    echo hi
    --before--
    hi
    $ make-v3 greeting 'CaCO3=$(WITH-OCTOTHORPE)'
    echo hi
    --before--
    hi

H. What does it mean to define a makefile variable lazily?
==========================================================

`make`'s `=` operator captures the symbolic representation of the
right-hand-side, unlike most languages which capture its value.

When a makefile variable's value is needed (to be printed, or in the case of
`SHELL`, to determine what to run), the definition is evaluated in terms of the
current values of any referenced variables instead of their values at definition
time.

This article uses this feature to define `SHELL` in terms of `CaCO3` once,
since the lookup for `CaCO3`'s value is deferred until it is actually needed,
allowing users to define `CaCO3` on a per-rule basis.

For more more on the lazy evaluation of `make` variables see [the description
of /recursively expanded/ variables in the make manual](https://www.gnu.org/software/make/manual/html_node/Flavors.html).

I. What does `define` do?
==============================

`define` is [`make`'s syntax for defining a multi-line variable](https://www.gnu.org/software/make/manual/html_node/Multi_002dLine.html):

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

J. What does `$@` mean?
==========================

`$@` is one of `make`'s automatic variables, set locally for each rule. It
resolves to the filename matched by the target.

Most often, this is simply used to avoid repeating the target name inside the
rule (especially useful if you decide to change the name of the target later).

However, since variables defined by `=` in the Makefile are lazily evaluated,
this makes it possible to have global variables (like APPEND-TO-TARGET) refer
to the current target's name:

```make
define APPEND-TO-TARGET
w(){
  echo "$$2" >>$@;
};w
endef
```

/bin/sh and other shells also have a variable named `$@` (escaped in the
Makefile as `$$@`) which is an array of all the arguments to a shell function.

For more on `make`'s automatic variables, see [the make manual](https://www.gnu.org/software/make/manual/html_node/Automatic-Variables.html).

For more more on the lazy evaluation of `make` variables see [the description
of /recursively expanded/ variables in the make manual](https://www.gnu.org/software/make/manual/html_node/Flavors.html).

For more on the shell variable `$@` see the description of `@` under "Special
Parameters" in `man bash`.

K. What does `.INTERMEDIATE` do?
=====================================

Sometimes it's necessary to generate /intermediate/ files as a step between
your input files and your ultimate product. These intermediate files serve no
purpose in-and-of themselves and can litter your source directory if not
cleaned up.

For example, if I compile several `.c` source files into `.o` object files, then
combine all the `.o` files into a single `.a` archive file, I have no use for the
`.o` files once I have the `.a` file. They're just cluttering my build directory
and can be deleted.

`make` can sometimes autodetect such intermediate files, but normally listing a
file as a target or prerequisite prevents such detection.  Adding the file as
a prerequisite of `.INTERMEDIATE` is how `make` can be explicitly told to
delete a file if it's generated as part of a chain.

I tagged the `APPEND-TO-FILE` file targets as `.INTERMEDIATE` as the only real
purpose of those files is to be used in the examples and tests, and won't be
needed after `make` completes.

For more on intermediate files, I recommend reading the ["Chains of Implicit Rules" section of the make manual](https://www.gnu.org/software/make/manual/html_node/Chained-Rules.html).

L. What does `.SILENT` do?
===============================

By default, `make` prints each recipe step before it is executed.

> If you specify prerequisites for `.SILENT`, then `make` will not print the
> recipe used to remake those particular files before executing them.

(from [the makefile manual on "Special Targets"](https://www.gnu.org/software/make/manual/html_node/Special-Targets.html))

More commonly, you'll see people silencing single steps of a recipe by
prefixing the step with `@` or running `make --silent` to silence all recipes.

I tagged the `APPEND-TO-TARGET` rules as `.SILENT` so that the echoing of the
recipe steps during file generation wouldn't be mistaken for the echoing
during the rules that depend on those files.

<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>
<br/>

M. Secret bonus appendix
========================

With some work, we can come up with a custom `SHELL` function that persists a
shell between recipe steps, can be used on a rule-by-rule basis, and works in
`make` version 3:

```makefile
define PERSIST
# Path for the named pipe used to pass a stream of recipe steps to a
# backgrounded persistent shell
entire_recipe=.$@-entire_recipe.fifo

# Path for the named pipe used to indicate when a single recipe step has
# finished running
recipe_step_complete=.$@-recipe_step_complete.fifo

start_background_shell_if_necessary(){
	# Since the background process deletes the pipes when the shell is complete,
	# assume that the background shell is running if and only if the pipes exist

	if ! [[ -p $$entire_recipe && -p $$recipe_step_complete ]]; then
		mkfifo $$entire_recipe $$recipe_step_complete

		# In a backgrounded process, run the entire recipe in a subshell and then
		# clean up the pipes
		{
			/bin/sh $$entire_recipe
			rm -f $$entire_recipe $$recipe_step_complete
		} &
	fi
}

run_recipe_step(){
	# Write the output of all the following commands to the recipe pipe for the
	# backgrounded shell.

	# As long as at least one process has a writable file handle for the recipe
	# pipe open, EOF will not be written to the pipe and the backgrounded shell
	# will continue trying to run commands from it.

	# If instead commands wrote to the recipe pipe individually, then EOF would
	# be written to the pipe at the end of each command, allowing the
	# backgrounded
	# shell to reach the "end" of the pipe and move on to cleanup prematurely.

	exec >$$entire_recipe

	recipe_step=$$2
	echo "$$recipe_step"

	# Use the output pipe as a synchronization lock to detect when the
	# backgrounded shell has finished running this recipe step. Otherwise, if we
	# did not wait, the output of one step might print after make echoes the next
	# recipe step
	echo "true > $$recipe_step_complete"
	cat $$recipe_step_complete >/dev/null

	# Use "sleep" to keep the recipe file handle open in the background
	# for long enough for make to call run_recipe_step again with the next
	# recipe step, preventing the background shell from ending between recipe
	# steps
	sleep .1 &
};

start_background_shell_if_necessary;
run_recipe_step
endef

.PHONY: persistent
persistent: CaCO3=$(PERSIST)
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

For one, it's not completely functional

It doesn't connect STDIN to the STDIN of the backgrounded shell, so it'll work
differently than a non-persistent shell there.

```makefile
.PHONY: using-stdin
using-stdin: CaCO3=$(PERSIST)
using-stdin:
	tr a-z A-Z
```

    $ echo "hello" | make using-stdin
    tr a-z A-Z
    $ echo "hello" | make SHELL=/bin/sh using-stdin
    tr a-z A-Z
    HELLO

Not to mention that it'll fail completely when used on a multiline `if`, `while`
or `for` loop, as the lines no longer run in lockstep with execution.

The shell script approach is simpler and more robust, even if it does create a
temporary file.
