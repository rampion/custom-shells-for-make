.DEFAULT_GOAL := test

################################################################################
### Testing examples from README.md ############################################
################################################################################

# All the example makefile snippets in README.md are followed by indented blocks
# showing their expected output when run.
#
# These expected outputs are also used as tests for the snippets, to make sure we
# don't accidentally lie about what the examples do.
#
# The tests are implemented using `cram` (https://bitheap.org/cram/), a simple
# test framework. It checks the file it's given for lines starting with '  $ ',
# and runs the commands on those lines. It then compares the actual output of
# each command with the expected output given on the following lines starting
# with '  '.
#
# Cram can be installed via pip (`pip3 install --user cram`) or using your
# preferred package manager.
#
# Since these tests are indented by four spaces (Markdown's syntax for a
# monospace block), we'll need to tell cram to use that for test detection,
# rather than the default of two spaces.

.PHONY: _test
_test:
	cram --indent=4 README.md

# GNU Make version 3 and 4 have slightly different behaviour in certain
# situations.
#
# README.md expects the $make_v3 and $make_v4 environment variables to contain
# paths to each executable, respectively, so it can demonstrate those
# differences.
export make_v3
make_v3=$(shell $(dir $(MAKEFILE_LIST))get_version make '^GNU Make 3\.')

export make_v4
make_v4=$(shell $(dir $(MAKEFILE_LIST))get_version make '^GNU Make 4\.')

# Most examples in the README.md just use `make`, so we should make sure
# they work whether that resolves to version 3 or version 4.
.PHONY: _test_v3
_test_v3: PATH:=$(dir $(make_v3)):$(PATH)
_test_v3: _test

.PHONY: _test_v4
_test_v4: PATH:=$(dir $(make_v4)):$(PATH)
_test_v4: _test

# By default, in some distributions of make, recursive calls to `make` (like
# those in the tests below) generate messages from `make` about which directory
# it's in.
#
# These messages contradict the expected output of the tests, so calling `make _test`
# directory produces spurious errors that don't occur when cram is run directly:
#
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
.PHONY: test
test:
	@make --no-print-directory _test_v3
	@make --no-print-directory _test_v4

README.makefile: $(dir $(MAKEFILE_LIST))README.md
	sed -n '/^ *```makefile$$/,/^ *```$$/{//g;s/^ *//;p;}' $< > $@

################################################################################
### Preview how github will render README.md ###################################
################################################################################

README.html: README.md
	pandoc $< -o $@ --css gfm.css --standalone --from gfm --to html --metadata=title:README --highlight-style pygments

################################################################################
### Remove generated files #####################################################
################################################################################

.PHONY: clean html file
clean:
	rm -f README.makefile README.html
