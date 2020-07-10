# This Makefile demonstrates how you can use `make`'s SHELL variable to
# customize how recipes are executed.

################################################################################
### Contents ###################################################################
################################################################################

# There are four main sections:
# 0. Testing the examples
# 1. Creating a custom SHELL
# 2. Writing recipes in non-shell programming languages
# 3. Persisting the shell betweens lines of the recipe

# There's also an appendix detailing various Makefile features some readers
# might not be familiar with:
# A. What's a recipe?
# B. What's a target?
# C. What's a rule?
# D. What's that .PHONY thing?
# E. What's that .DEFAULT_GOAL thing?
# F. What's that define thing?
# G. Why did you start listing targets twice?
# H. Why are you using double dollar signs everywhere ($$)?
# I. What's that $@ thing?
# J. What's that .INTERMEDIATE thing?
# K. What's that .SILENT thing?

################################################################################
### 0. Testing the examples ####################################################
################################################################################

# All the examples in later sections are followed by multi-line `define -`
# blocks showing their expected output when run.

# These expected outputs are also used as tests for this Makefile, to make sure
# we don't accidentally lie about what the examples do. To run the tests, just
# save the file to your machine, then run `make` or `make test` in the
# directory containing this Makefile.

# If you want to know how the tests work, read on! If not, feel free to skip to
# the next section, "Creating a custom SHELL".

.PHONY: _test
_test:
	cram Makefile

# The tests are implemented using `cram` (https://bitheap.org/cram/), a simple
# test framework. It checks the file it's given for lines starting with '  $ ',
# and runs the commands on those lines. It then compares the actual output of
# each command with the expected output given on the following lines starting
# with '  '.

# Cram can be installed via pip (`pip3 install --user cram`) or using your
# preferred package manager.

# Since all the tests use this Makefile, we'll need to copy it to the temporary
# directory `cram` has set up to run the tests in.

define -
  $ cp $TESTDIR/Makefile .
endef

.PHONY: test
test:
	@make --no-print-directory _test

.DEFAULT_GOAL := test

# By default, in some distributions of make, recursive calls to `make` (like
# those in the tests below) generate messages from `make` about which directory
# it's in.
#
# These messages contradict the expected output of the tests, so calling `make _test`
# directory produces spurious errors that don't occur when cram is run directly:
#
#     $ cram Makefile
#     .
#     # Ran 1 tests, 0 skipped, 0 failed.
#     $ make _test
#     cram Makefile
#     !
#     --- Makefile
#     +++ Makefile.err
#     @@ -107,6 +107,8 @@
#
#      define -
#        $ make by-default
#     +  make[1]: Entering directory `/private/var/folders/81/2lqb_j7n0670jbcb_btpn5nm0000gn/T/cramtests-4ib9m0aw/Makefile'
#        echo $0
#        /bin/sh
#     +  make[1]: Leaving directory `/private/var/folders/81/2lqb_j7n0670jbcb_btpn5nm0000gn/T/cramtests-4ib9m0aw/Makefile'
#       endef
#     …
#     # Ran 1 tests, 0 skipped, 1 failed
#     make: *** [_test] Error 1
#
# The `test` target is a simple wrapper that disables the default behaviour of
# printing directory messages so we don't have to account for these messages.

################################################################################
### 1. Creating a custom SHELL #################################################
################################################################################

# By default, `make` runs each line of a recipe in /bin/sh

.PHONY: by-default
by-default:
	echo $$0

define -
  $ make by-default
  echo $0
  /bin/sh
endef

# The shell `make` uses can be changed by setting the `SHELL` Makefile variable,
# either globally or per-rule:

.PHONY: use-bash
use-bash: SHELL=/bin/bash
use-bash:
	echo $$0

define -
  $ make use-bash
  echo $0
  /bin/bash
endef

# The value of `SHELL` doesn't have to be a path to an executable file, though.
# It can contain an arbitrary `sh` command.

# The only requirement is that the command can be run with two arguments; `-c`
# and the current recipe line.

# A key observation is that the command only needs to end in something that can
# accept the `-c` and the recipe line. We can run other `sh` commands first and
# then tack on a call to `/bin/sh` with `;`.

# For example, we could run something before each recipe line:

.PHONY: before-each-line
before-each-line: SHELL=echo '---before---';/bin/sh
before-each-line:
	echo one
	echo two
	echo three

define -
  $ make before-each-line
  echo one
  ---before---
  one
  echo two
  ---before---
  two
  echo three
  ---before---
  three
endef

# As a more practical use case, I could use this functionality to load a python
# virtual environment into the shell before running a recipe line, removing the
# duplication in a set of rules like:
#
#     dist/wigit-%.tar.gz: setup.py ${SRC} .venv/bin/activate
#       . .venv/bin/activate; ./setup.py --quiet sdist
#
#     # check the code for style problems
#     pep8: .venv/bin/activate
#       . .venv/bin/activate; pycodestyle setup.py ${SRC}
#       
#     # run a python3 repl with the virtualenv in scope
#     repl: .venv/bin/activate
#       . .venv/bin/activate; python3

# It's a little awkward trying to fit long commands into a one-liner next to
# the rule's SHELL definition, so we'll start using `make`'s `define` syntax
# for multi-line variable assignments.

define BEFORE-EACH-LINE
echo '---before---';
/bin/sh
endef

.PHONY: before-with-define
before-with-define: SHELL=$(BEFORE-EACH-LINE)
before-with-define:
	echo one
	echo two
	echo three

define -
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
endef

# `define`-blocks are pretty nice, except newlines don't terminate commands as
# they would in a shell script when the command is invoked as SHELL, so there's
# a couple of things to look out for:

# - you have to terminate each command with a semicolon since all the lines are
#   effectively strung together

define MISSING-SEMICOLON
echo 'the shell call becomes an argument to echo'
/bin/sh
endef

.PHONY: missing-semicolon
missing-semicolon: SHELL=$(MISSING-SEMICOLON)
missing-semicolon:
	oops

define -
  $ make missing-semicolon
  oops
  the shell call becomes an argument to echo
  /bin/sh -c oops
endef

# - you can't use an octothorpe (#) to create comments in the `define`-block as
#   it will cause all the following lines to be commented out

define WITH-OCTOTHORPE
echo 'the shell call gets commented out';
# and now we call the shell;
/bin/sh
endef

.PHONY: with-octothorpe
with-octothorpe: SHELL=$(WITH-OCTOTHORPE)
with-octothorpe:
	oops

define -
  $ make with-octothorpe
  oops
  the shell call gets commented out
endef

# But with those restrictions in mind, we can still do some pretty interesting
# things before invoking the shell.

# For example, we could use the shell's `trap` command to run code when the
# shell exits, in effect setting up code to be called after each line of the
# recipe:

define AFTER-EACH-LINE
trap 'echo ---after---' EXIT;
/bin/sh
endef

.PHONY: after-each-line
after-each-line: SHELL=$(AFTER-EACH-LINE)
after-each-line:
	echo one
	echo two
	echo three

define -
  $ make after-each-line
  echo one
  one
  ---after---
  echo two
  two
  ---after---
  echo three
  three
  ---after---
endef

# Or we could define a custom function to make available to the shell

define CUSTOM-FUNCTION
log(){
	echo "<log message='$$@'/>";
};
export -f log;
/bin/sh
endef

.PHONY: with-custom-function
with-custom-function: SHELL=$(CUSTOM-FUNCTION)
with-custom-function:
	log she sells sea shells by the sea shore
	log pad kid poured curd pulled cod

define -
  $ make with-custom-function
  log she sells sea shells by the sea shore
  <log message='she sells sea shells by the sea shore'/>
  log pad kid poured curd pulled cod
  <log message='pad kid poured curd pulled cod'/>
endef

# This whole time we've been passing the `-c` <recipe-line> arguments to a
# shell, but shells aren't the only commands that can be called this way.

# For example, `/bin/echo` will happily take `-c`:

.PHONY: use-echo
use-echo: SHELL=/bin/echo
use-echo:
	unique new york
	red leather yellow leather

define -
  $ make use-echo
  unique new york
  -c unique new york
  red leather yellow leather
  -c red leather yellow leather
endef

# (`echo`'s not particularly exciting)

# But what about other commands that either don't take `-c` or don't do what we
# want with it?

# Pulling a trick out of `git-config`'s book, we could also use the command
# specified by `SHELL` to define a shell function and let that function be
# called with `-c` and the current recipe line.

# For example, we could define a function that just inspects its arguments
# and have each recipe line invoked with that as its "shell":

define INSPECT
inspect(){
	echo "\$$# = $$#";
	echo "\$$0 = $$0";
	echo "\$$1 = $$1";
	echo "\$$2 = $$2";
};inspect
endef

.PHONY: with-inspect
with-inspect: SHELL=$(INSPECT)
with-inspect:
	Peter Piper picked a peck of pickled peppers
	I wish I wore an irish wristwatch

define -
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
endef

# As a more practical use-case, this technique could be used to generate a file
# without wrapping each line in `echo "…" >>target`:

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
cheese-list.txt: SHELL=$(APPEND-TO-TARGET)
cheese-list.txt:
	· cheddar
	· edam
	· mozzerella
	· queso fresco
	· brie

define -
  $ make file-demo
  cat cheese-list.txt
  · cheddar
  · edam
  · mozzerella
  · queso fresco
  · brie
  rm cheese-list.txt
endef

################################################################################
### 2. Writing recipes in non-shell programming languages ######################
################################################################################

# This technique of defining a function and letting it be called with the
# SHELL's arguments is extremely powerful as it lets us arbitrarily manipulate
# those arguments, pass them to whatever commands we want, and manipulate those
# commands' output.

# For example, we could interpret the recipe lines in a non-shell programming
# language, like ruby.

# Here we pass the recipe line to ruby, asking it to evaluate the line and
# print its resulting value.

define RUBY
r(){
	ruby -e "p ($$2)" | sed 's/^/# /';
}; r
endef

.PHONY: in-ruby
in-ruby: SHELL=$(RUBY)
in-ruby:
	puts "hello ruby!"
	Struct.new(:a,:b).new(1,2)

define -
  $ make in-ruby
  puts "hello ruby!"
  # hello ruby!
  # nil
  Struct.new(:a,:b).new(1,2)
  # #<struct a=1, b=2>
endef

# Or we could use haskell with its repl, `ghci`. The haskell compiler is less
# commonly installed than ruby, so we better test for that:

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
in-haskell: SHELL=$(GHCI)
in-haskell:
	putStrLn "hello haskell!"
	let fibs = 1 : 1 : zipWith (+) fibs (tail fibs) in take 10 fibs

define -
  $ make in-haskell
  putStrLn "hello haskell!"
  -- hello haskell!
  let fibs = 1 : 1 : zipWith (+) fibs (tail fibs) in take 10 fibs
  -- [1,1,2,3,5,8,13,21,34,55]
endef

# Neither of those is as popular as python, so let's give that a whilr,
# with some useful imports for file manipulation:

define PYTHON
p(){
	exec python3 -c "import pathlib,os,shutil,sys;print(repr($$2))" | sed 's/^/# /';
}; p
endef

.PHONY: in-python
in-python: SHELL=$(PYTHON)
in-python:
	print("hello from python!")
	pathlib.Path('a-file').touch()
	os.mkdir('a-dir')
	shutil.move('a-file','a-dir')
	os.listdir('a-dir')
	shutil.rmtree('a-dir')

define -
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
endef

################################################################################
### 3. Persisting the shell between lines of the recipe ########################
################################################################################

# One of the things that surprises many people new to `make` is that the shell
# used in recipes is non-persistent; that is, a new shell is invoked for each
# line of the recipe.

.PHONY: non-persistent
non-persistent:
	x=1
	y=2
	echo $${x:-unset}
	echo $${y:-unset}

define -
  $ make non-persistent
  x=1
  y=2
  echo ${x:-unset}
  unset
  echo ${y:-unset}
  unset
endef

# In the above example, `x` and `y` are unset because the shells that set x and
# y have both closed, taking their settings with them.

# With some work though, we can use a custom SHELL function to pass recipe lines
# to a persistent shell that runs in the background

define PERSIST
:	Path for the named pipe used to pass a stream of recipe lines to a
	backgrounded persistent shell;
entire_recipe=.$@-entire_recipe.fifo;

:	Path for the named pipe used to indicate when a single recipe line has
	finished running;
recipe_line_complete=.$@-recipe_line_complete.fifo;

start_background_shell_if_necessary(){
	:	Since the background process deletes the pipes when the shell is complete,
		assume that the background shell is running if and only if the pipes exist;

	if ! [[ -p $$entire_recipe && -p $$recipe_line_complete ]]; then
		mkfifo $$entire_recipe $$recipe_line_complete;

		:	In a backgrounded process, run the entire recipe in a subshell and then
			clean up the pipes;
		{
			/bin/sh $$entire_recipe;
			rm -f $$entire_recipe $$recipe_line_complete;
		} &
	fi;
};

run_recipe_line(){
	:	Write the output of all the following commands to the recipe pipe for the
		backgrounded shell. 

		As long as at least one process has a writable file handle for the recipe
		pipe open, EOF will not be written to the pipe and the backgrounded shell
		will continue trying to run commands from it.

		If instead commands wrote to the recipe pipe individually, then EOF would
		be written to the pipe at the end of each command, allowing the backgrounded
		shell to reach the "end" of the pipe and move on to cleanup prematurely.
	;
	exec >$$entire_recipe;

	recipe_line=$$2;
	echo "$$recipe_line";

	:	Use the a pipe as a synchronization lock to detect when the backgrounded
		shell has finished running this recipe line. Otherwise, if we did not wait,
		the output of one line might print after make echoes the next recipe line;
	echo "true > $$recipe_line_complete";
	cat $$recipe_line_complete >/dev/null;

	:	Use "sleep" to keep the recipe file handle open in the background
		for long enough for make to call run_recipe_line again with the next
		recipe line, preventing the background shell from ending between recipe
		lines;
	sleep .1 &
};

start_background_shell_if_necessary;
run_recipe_line
endef

.PHONY: persistent
persistent: SHELL=$(PERSIST)
persistent:
	x=1
	y=2
	echo $${x:-unset}
	echo $${y:-unset}

define -
  $ make persistent
  x=1
  y=2
  echo ${x:-unset}
  1
  echo ${y:-unset}
  2
endef


# It is not a trivial chunk of scripting, but it can be done!
#
# But should it be used? No, probably not.
#
# For one, it's not completely functional; it doesn't connect STDIN to the STDIN
# of the backgrounded shell, so it'll work differently than a non-persistent
# shell there.

.PHONY: using-stdin
using-stdin: SHELL=$(PERSIST)
using-stdin:
	tr a-z A-Z

define -
  $ echo "hello" | make using-stdin
  tr a-z A-Z
  $ echo "hello" | make SHELL=/bin/sh using-stdin
  tr a-z A-Z
  HELLO
endef

# But even without that issue, there's no driving need for such a complicated
# solution.  Recipes can already be split across multiple lines using
# backslashes:

.PHONY: multiline
multiline:
	x=1;\
	y=2;\
	echo $${x:-unset};\
	echo $${y:-unset}

define -
  $ make multiline
  x=1;\
  	y=2;\
  	echo ${x:-unset};\
  	echo ${y:-unset}
  1
  2
endef

# More complex stateful operations that require a persistent shell should
# probably become their own shell script. Many shells can be told to print
# commands before running them using '-v'

.PHONY: shell-script
shell-script: script.sh
	/bin/sh -v $<

.INTERMEDIATE: script.sh
.SILENT: script.sh
script.sh: SHELL=$(APPEND-TO-TARGET)
script.sh:
	x=1
	y=2
	echo $${x:-unset}
	echo $${y:-unset}

define -
  $ make shell-script
  /bin/sh -v script.sh
  x=1
  y=2
  echo ${x:-unset}
  1
  echo ${y:-unset}
  2
  rm script.sh
endef

# As with any technique, custom SHELLs can be misused, but if used correctly
# they provide an opportunity to remove unnecessary repetition from your
# Makefile and make it easier to focus on what's important.

################################################################################
### APPENDIX ###################################################################
################################################################################
#
# A. What's a recipe?
# B. What's a target?
# C. What's a rule?
# ===================
#
# Here's how the make manual defines rule, recipe, and target:
#
# > A simple makefile consists of /rules/ with the following shape:
# >
# >   target … : prerequisites …
# >   	recipe
# >   	…
# >   	…
# >
# > A /target/ is usually the name of a file that is generated by a program;
# > examples of targets are executables or object files. A target can also be
# > the name of an action to carry out, such as 'clean' (see Phony Targets).
# >
# > A /prerequisite/ is a file that is used as input to create the target. A
# > target often depends on several files.
# >
# > A /recipe/ is an action that `make` carries out. A recipe may have more than
# > one command, either on the same line or each on its own line. **Please
# > note:** you need to put a tab character at the beginning of every recipe
# > line! This is an obscurity that catches the unwary. […]
#
# (https://www.gnu.org/software/make/manual/make.html#What-a-Rule-Looks-Like)
#
# D. What's that .PHONY thing?
# ============================
#
# By default, `make` assumes its targets are actual files. If a file with the
# same name as the target exists and is newer than all its prerequisites, `make`
# won't bother to run its rule, assuming the file is already up-to-date.
#
# > A phony target is one that is not really the name of a file; rather it is
# > just a name for a recipe to be executed when you make an explicit request.
# > There are two reasons to use a phony target; to avoid a conflict with a file
# > of the same name, and to improve performance.
# >
# > […]
# >
# > [Y]ou can explicitly declare the target to be phony by making it a
# > prerequisite of the special target `.PHONY` (see Special Built-in Target
# > Names) as follows:
# >
# >   .PHONY: clean
# >   clean:
# >   	rm *.o temp
# >
# > Once this is done, `make clean` will run the recipe regardless of whether
# > there is a file named `clean`.
#
# (https://www.gnu.org/software/make/manual/html_node/Phony-Targets.html)
#
# WHile declaring targets `.PHONY` isn't strictly necessary, I stick to it here
# as I consider it good style.
#
# E. What's that .DEFAULT_GOAL thing?
# ===================================
#
# `.DEFAULT_GOAL` is a special variable in `make`. If specified, it determines
# which rule is run when `make` is run at the command line with no arguments. If
# undefined, `make` just executes the first rule in the Makefile when called
# with no arguments.
#
# For more details, see the description of `.DEFAULT_GOAL` in the Special
# Variables section of the make manual
# (https://www.gnu.org/software/make/manual/html_node/Special-Variables.html).
#
# F. What's that define thing?
# ============================
#
# `define` is `make`'s syntax for defining a multi-line variable:
#
# > Another way to set the value of a variable is to use the `define` directive.
# > This directive has an unusual syntax which allows newline characters to be
# > included in the value, which is convenient for defining both canned
# > sequences of commands (see Defining Canned Recipes), and also sections of
# > makefile syntax to use with eval (see Eval Function).
# >
# > The `define` directive is followed on the same line by the name of the
# > variable being defined and an (optional) assignment operator, and nothing
# > more. The value to give the variable appears on the following lines. The end
# > of the value is makred by a line containing just the word `endef`.
#
# (https://www.gnu.org/software/make/manual/html_node/Multi_002dLine.html)
#
# G. Why did you start listing targets twice?
# ===========================================
#
# In the rule definition:
#
#   use-bash: SHELL=/bin/bash
#   use-bash:
#
# I'm using `make`'s syntax for target-specific variable assignments. The
# variable assignments need to go on a separate line than the prerequisites
# (even if a target has no prerequisites):
#
# > Variable values in `make` are usually global; that is, they are the same
# > regardless of where they are evaluated (unless they're reset, of course). One
# > exception to that is automatic variables (see Automatic Variables).
# >
# > The other exception is /target-specific variable values/. This feature
# > allows you to define different values for the same variable, based on the
# > target `make` is currently building. As with automatic variables, these
# > values are only available within the context of a target's recipe (and in
# > other target-specific assignments).
#
# (https://www.gnu.org/software/make/manual/html_node/Target_002dspecific.html)
#
# H. Why are you using double dollar signs everywhere ($$)?
# =========================================================
#
# `$` is used by `make` to introduce its variables and function calls, so to use
# `$` in a recipe line it must be escaped. `make` expands `$$` to just `$`
# before evaluating recipe lines.
#
# For more details, see the make manual:
# (https://www.gnu.org/software/make/manual/html_node/Reference.html)
#
# I. What's that $@ thing?
# ========================
#
# `$@` is one of `make`'s automatic variables, set locally for each rule. It
# resolves to the filename matched by the target.
#
# Most often, this is simply used to avoid repeating the target name inside the
# rule (especially useful if you decide to change the name of the target later).
#
# However, since variables defined by `=` in the Makefile are lazily evaluated,
# this makes it possible to have global variables (like APPEND-TO-TARGET) refer
# to the current target's name:
#
#   define APPEND-TO-TARGET
#   w(){
#   	echo "$$2" >>$@;
#   };w
#   endef
#
# /bin/sh and other shells also have a variable named `$@` (escaped in the
# Makefile as `$$@`) which is an array of all the arguments to a shell function.
#
# For more on `make`'s automatic variables, see the make manual
# (https://www.gnu.org/software/make/manual/html_node/Automatic-Variables.html).
#
# For more more on the lazy evaluation of `make` variables see the description
# of /recursively expanded/ variables in the make manual
# (https://www.gnu.org/software/make/manual/html_node/Flavors.html).
#
# For more on the shell variable `$@` see the description of `@` under "Special
# Parameters" in `man bash`.
#
# J. What's that .INTERMEDIATE thing?
# ===================================
#
# Sometimes it's necessary to generate /intermediate/ files as a step between
# your input files and your ultimate product. These intermediate files serve no
# purpose in-and-of themselves and can litter your source directory if not
# cleaned up.
#
# For example, if I compile several .c source files into .o object files, then
# combine all the .o files into a single .a archive file, I have no use for the
# .o files once I have the .a file. They're just cluttering my build directory
# and can be deleted.
#
# Make can sometimes autodetect such intermediate files, but normally listing a
# file as a target or prerequisite prevents such detection.  Adding the file as
# a prerequisite of `.INTERMEDIATE` is how `make` can be explicitly told to
# delete a file if it's generated as part of a chain.
#
# I tagged the `APPEND-TO-FILE` file targets as `.INTERMEDIATE` as the only real
# purpose of those files is to be used in the examples and tests, and won't be
# needed after `make` completes.
#
# For more on intermediate files, I recommend reading the "Chains of Implicit
# Rules" section of the make manual
# (https://www.gnu.org/software/make/manual/html_node/Chained-Rules.html).
#
# K. What's that .SILENT thing?
# =============================
#
# By default, `make` prints each recipe line before it is executed.
#
# > If you specify prerequisites for `.SILENT`, then `make` will not print the
# > recipe used to remake those particular files before executing them.
#
# (https://www.gnu.org/software/make/manual/html_node/Special-Targets.html)
#
# More commonly, you'll see people silencing single lines of a recipe by
# prefixing the line with `@` or running `make --silent` to silence all recipes.
#
# I tagged the `APPEND-TO-TARGET` rules as `.SILENT` so that the echoing of the
# recipe lines during file generation wouldn't be mistaken for the echoing
# during the rules that depend on those files.
