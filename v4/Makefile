# GOAL: figure out how to wrap/escape make-v3 compatible shells for use with
# make-v4 (/nix/store/cy372pb1blsarl5vin27lsp5dmaplbyw-gnumake-4.2.1/bin/make)
PATH := /nix/store/cy372pb1blsarl5vin27lsp5dmaplbyw-gnumake-4.2.1/bin:.:$(PATH)

define -
  $ cp $TESTDIR/{inspect,Makefile} .
endef

test:
	make --no-print-directory _test

_test:
	cram -i Makefile

recipe: CUSTOM=/bin/echo "--before--"; /bin/sh
recipe:
	@$(info # $(SHELL))
	echo "1 + 1 = $$((1 + 1))"

define -
  $ make recipe
  # /bin/sh
  echo "1 + 1 = $((1 + 1))"
  1 + 1 = 2
endef

inspect: SHELL=inspect
inspect: recipe

define -
  $ make inspect
  # inspect
  echo "1 + 1 = $((1 + 1))"
  ["-c", "echo \"1 + 1 = $((1 + 1))\""]
endef

SUBSH=/bin/sh -c $(1)\ "$$@" shellname

subsh-inspect: SHELL=$(call SUBSH,./inspect)
subsh-inspect: recipe

define -
  $ make subsh-inspect
  # /bin/sh -c ./inspect\ "$@" shellname
  echo "1 + 1 = $((1 + 1))"
  ["-c", "echo \"1 + 1 = $((1 + 1))\""]
endef

makevar: SHELL=$(CUSTOM)
makevar: recipe

define -
  $ make makevar
  # /bin/echo "--before--"; /bin/sh
  echo "1 + 1 = $((1 + 1))"
  "--before--"; /bin/sh -c echo "1 + 1 = $((1 + 1))"
endef

inspect-makevar: SHELL=inspect $(CUSTOM)
inspect-makevar: recipe

define -
  $ make inspect-makevar
  # inspect /bin/echo "--before--"; /bin/sh
  echo "1 + 1 = $((1 + 1))"
  ["/bin/echo", "\"--before--\";", "/bin/sh", "-c", "echo \"1 + 1 = $((1 + 1))\""]
endef

subsh-makevar: SHELL=$(call SUBSH,$(CUSTOM))
subsh-makevar: recipe

define -
  $ make subsh-makevar
  # /bin/sh -c /bin/echo "--before--"; /bin/sh\ "$@" shellname
  echo "1 + 1 = $((1 + 1))"
  
endef

export CUSTOM

envvar: SHELL=$$CUSTOM
envvar: recipe

define -
  $ make envvar
  # $CUSTOM
  echo "1 + 1 = $((1 + 1))"
  make[2]: $CUSTOM: Command not found
  make[2]: *** [Makefile:18: recipe] Error 127
  [2]
endef

inspect-envvar: SHELL=inspect $$CUSTOM
inspect-envvar: recipe

define -
  $ make inspect-envvar
  # inspect $CUSTOM
  echo "1 + 1 = $((1 + 1))"
  ["$CUSTOM", "-c", "echo \"1 + 1 = $((1 + 1))\""]
endef

subsh-envvar: SHELL=$(call SUBSH,$$CUSTOM)
subsh-envvar: recipe

define -
  $ make subsh-envvar
  # /bin/sh -c $CUSTOM\ "$@" shellname
  echo "1 + 1 = $((1 + 1))"
  "--before--"; /bin/sh -c echo "1 + 1 = $((1 + 1))"
endef

eval-envvar: SHELL=eval $$CUSTOM
eval-envvar: recipe

define -
  $ make eval-envvar
  # eval $CUSTOM
  echo "1 + 1 = $((1 + 1))"
  "--before--"; /bin/sh -c echo 1 + 1 = 2
endef

subsh-eval-envvar: SHELL=$(call SUBSH,eval\ "$$CUSTOM")
subsh-eval-envvar: recipe

define -
  $ make subsh-eval-envvar
  # /bin/sh -c eval\ "$CUSTOM"\ "$@" shellname
  echo "1 + 1 = $((1 + 1))"
  --before--
  
endef

solution: SHELL=$(call SUBSH,eval\ "f(){\ $$CUSTOM\ "'"$$@"'";\ }";\ f)
solution: recipe

define -
  $ make solution
  # /bin/sh -c eval\ "f(){\ $CUSTOM\ "'"$@"'";\ }";\ f\ "$@" shellname
  echo "1 + 1 = $((1 + 1))"
  --before--
  1 + 1 = 2
endef

#SHELL = /bin/sh -c echo\ --before--;\ /bin/sh\ "$$@" _
#SHELL = ruby -e 'p ARGV' $$CUSTOM\ "$$@"

#debug: SHELL := /bin/sh -c ./inspect\ $$CUSTOM\ $$(printf\ %q\ "$$@") _
#debug: SHELL := /bin/sh -c ./inspect _
