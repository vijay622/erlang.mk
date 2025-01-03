# Dialyzer plugin.

dialyzer_TARGETS = $(call list_targets,dialyzer)

dialyzer_TARGETS_SET_1 = dialyzer-app dialyzer-apps-only dialyzer-apps-with-local-deps
dialyzer_TARGETS_SET_2 = dialyzer-beam dialyzer-check dialyzer-custom-plt dialyzer-deps
dialyzer_TARGETS_SET_3 = dialyzer-erlc-opts dialyzer-local-deps dialyzer-opts dialyzer-plt-apps
dialyzer_TARGETS_SET_4 = dialyzer-plt-ebin-only dialyzer-plt-swallow-warnings dialyzer-pt

ifneq ($(filter-out $(dialyzer_TARGETS_SET_1) $(dialyzer_TARGETS_SET_2) $(dialyzer_TARGETS_SET_3) $(dialyzer_TARGETS_SET_4),$(dialyzer_TARGETS)),)
$(error Dialyzer target missing from dialyzer_TARGETS_SET_* variables.)
endif

ifdef SET
dialyzer_TARGETS := $(dialyzer_TARGETS_SET_$(SET))
endif

ifneq ($(shell which sem 2>/dev/null),)
	DIALYZER_MUTEX = sem --fg --id dialyzer
endif

.PHONY: dialyzer $(dialyzer_TARGETS)

dialyzer: $(dialyzer_TARGETS)

dialyzer-app: init

	$i "Bootstrap a new OTP application named $(APP)"
	$t mkdir $(APP)/
	$t cp ../erlang.mk $(APP)/
	$t $(MAKE) -C $(APP) -f erlang.mk bootstrap $v

	$i "Run Dialyzer"
	$t $(DIALYZER_MUTEX) $(MAKE) -C $(APP) dialyze $v

	$i "Check that the PLT file was created"
	$t test -f $(APP)/.$(APP).plt

	$i "Create a module with a function that has no local return"
	$t printf "%s\n" \
		"-module(warn_me)." \
		"-export([doit/0])." \
		"doit() -> 1 = 2, ok." > $(APP)/src/warn_me.erl

	$i "Confirm that Dialyzer errors out"
	$t ! $(DIALYZER_MUTEX) $(MAKE) -C $(APP) dialyze $v

	$i "Distclean the application"
	$t $(MAKE) -C $(APP) distclean $v

	$i "Check that the PLT file was removed"
	$t test ! -e $(APP)/.$(APP).plt

dialyzer-apps-only: init

	$i "Create a multi application repository with no root application"
	$t mkdir $(APP)/
	$t cp ../erlang.mk $(APP)/
	$t echo "include erlang.mk" > $(APP)/Makefile

	$i "Create a new application my_app"
	$t $(MAKE) -C $(APP) new-app in=my_app $v

	$i "Create a module my_server from gen_server template in my_app"
	$t $(MAKE) -C $(APP) new t=gen_server n=my_server in=my_app $v

	$i "Add Cowlib to the list of dependencies"
	$t perl -ni.bak -e 'print;if ($$.==1) {print "DEPS = cowlib\n"}' $(APP)/apps/my_app/Makefile

	$i "Run Dialyzer"
	$t $(DIALYZER_MUTEX) $(MAKE) -C $(APP) dialyze $v

	$i "Check that the PLT file was created automatically"
	$t test -f $(APP)/.$(APP).plt

	$i "Confirm that Cowlib was included in the PLT"
	$t dialyzer --plt_info --plt $(APP)/.$(APP).plt | grep -q cowlib

	$i "Create a module with a function that has no local return"
	$t printf "%s\n" \
		"-module(warn_me)." \
		"-export([doit/0])." \
		"doit() -> 1 = 2, ok." > $(APP)/apps/my_app/src/warn_me.erl

	$i "Confirm that Dialyzer errors out"
	$t ! $(DIALYZER_MUTEX) $(MAKE) -C $(APP) dialyze $v

dialyzer-apps-with-local-deps: init

	$i "Create a multi application repository with no root application"
	$t mkdir $(APP)/
	$t cp ../erlang.mk $(APP)/
	$t echo "include erlang.mk" > $(APP)/Makefile

	$i "Create a new application my_app"
	$t $(MAKE) -C $(APP) new-app in=my_app $v

	$i "Create a new application my_core_app"
	$t $(MAKE) -C $(APP) new-app in=my_core_app $v

	$i "Add my_core_app to the list of local dependencies for my_app"
	$t perl -ni.bak -e 'print;if ($$.==1) {print "LOCAL_DEPS = my_core_app\n"}' $(APP)/apps/my_app/Makefile

	$i "Run Dialyzer"
	$t $(DIALYZER_MUTEX) $(MAKE) -C $(APP) dialyze $v

	$i "Check that the PLT file was created automatically"
	$t test -f $(APP)/.$(APP).plt

	$i "Confirm that my_core_app was NOT included in the PLT"
	$t ! dialyzer --plt_info --plt $(APP)/.$(APP).plt | grep -q my_core_app

dialyzer-beam: init

	$i "Bootstrap a new OTP application named $(APP)"
	$t mkdir $(APP)/
	$t cp ../erlang.mk $(APP)/
	$t $(MAKE) -C $(APP) -f erlang.mk bootstrap $v

	$i "Add lager to the list of dependencies"
	$t perl -ni.bak -e 'print;if ($$.==1) {print "DEPS = lager\ndep_lager = git https://github.com/erlang-lager/lager master\n"}' $(APP)/Makefile

	$i "Add lager_transform to ERLC_OPTS"
	$t echo "ERLC_OPTS += +'{parse_transform, lager_transform}'" >> $(APP)/Makefile

	$i "Make Dialyzer use the beam files"
	$t perl -ni.bak -e 'print;if ($$.==1) {print "DIALYZER_DIRS = -r ebin\n"}' $(APP)/Makefile

	$i "Create a module that calls lager"
	$t printf "%s\n" \
		"-module(use_lager)." \
		"-export([doit/0])." \
		"doit() -> lager:error(\"Some message\")." > $(APP)/src/use_lager.erl

	$i "Run Dialyzer"
	$t $(DIALYZER_MUTEX) $(MAKE) -C $(APP) dialyze $v

	$i "Clean the application"
	$t $(MAKE) -C $(APP) clean $v

	$i "Run Dialyzer again using the produced PLT file"
	$t $(DIALYZER_MUTEX) $(MAKE) -C $(APP) dialyze $v

dialyzer-check: init

	$i "Bootstrap a new OTP application named $(APP)"
	$t mkdir $(APP)/
	$t cp ../erlang.mk $(APP)/
	$t $(MAKE) -C $(APP) -f erlang.mk bootstrap $v

	$i "Run 'make check'"
	$t $(DIALYZER_MUTEX) $(MAKE) -C $(APP) check $v

	$i "Check that the PLT file was created"
	$t test -f $(APP)/.$(APP).plt

	$i "Create a module with a function that has no local return"
	$t printf "%s\n" \
		"-module(warn_me)." \
		"-export([doit/0])." \
		"doit() -> 1 = 2, ok." > $(APP)/src/warn_me.erl

	$i "Confirm that Dialyzer errors out on 'make check'"
	$t ! $(DIALYZER_MUTEX) $(MAKE) -C $(APP) check $v

dialyzer-custom-plt: init

	$i "Bootstrap a new OTP application named $(APP)"
	$t mkdir $(APP)/
	$t cp ../erlang.mk $(APP)/
	$t $(MAKE) -C $(APP) -f erlang.mk bootstrap $v

	$i "Set a custom DIALYZER_PLT location"
	$t perl -ni.bak -e 'print;if ($$.==1) {print "DIALYZER_PLT = custom.plt\n"}' $(APP)/Makefile

	$i "Run Dialyzer"
	$t $(DIALYZER_MUTEX) $(MAKE) -C $(APP) dialyze $v

	$i "Check that the PLT file was created"
	$t test -f $(APP)/custom.plt

	$i "Distclean the application"
	$t $(MAKE) -C $(APP) distclean $v

	$i "Check that the PLT file was removed"
	$t test ! -e $(APP)/custom.plt

dialyzer-deps: init

	$i "Bootstrap a new OTP application named $(APP)"
	$t mkdir $(APP)/
	$t cp ../erlang.mk $(APP)/
	$t $(MAKE) -C $(APP) -f erlang.mk bootstrap $v

	$i "Add Cowlib to the list of dependencies"
	$t perl -ni.bak -e 'print;if ($$.==1) {print "DEPS = cowlib\n"}' $(APP)/Makefile

	$i "Run Dialyzer"
	$t $(DIALYZER_MUTEX) $(MAKE) -C $(APP) dialyze $v

	$i "Check that the PLT file was created"
	$t test -f $(APP)/.$(APP).plt

	$i "Confirm that Cowlib was included in the PLT"
	$t dialyzer --plt_info --plt $(APP)/.$(APP).plt | grep -q cowlib

dialyzer-erlc-opts: init

	$i "Bootstrap a new OTP application named $(APP)"
	$t mkdir $(APP)/
	$t cp ../erlang.mk $(APP)/
	$t $(MAKE) -C $(APP) -f erlang.mk bootstrap $v

	$i "Create a header file in a non-standard directory"
	$t mkdir $(APP)/exotic-include-path/
	$t touch $(APP)/exotic-include-path/dialyze.hrl

	$i "Create a module that includes this header"
	$t printf "%s\n" \
		"-module(no_warn)." \
		"-export([doit/0])." \
		"-include(\"dialyze.hrl\")." \
		"doit() -> ?OK." > $(APP)/src/no_warn.erl

	$i "Point ERLC_OPTS to the non-standard include directory"
	$t perl -ni.bak -e 'print;if ($$.==1) {print "ERLC_OPTS += -I exotic-include-path -DOK=ok\n"}' $(APP)/Makefile

	$i "Run Dialyzer"
	$t $(DIALYZER_MUTEX) $(MAKE) -C $(APP) dialyze $v

dialyzer-local-deps: init

	$i "Bootstrap a new OTP application named $(APP)"
	$t mkdir $(APP)/
	$t cp ../erlang.mk $(APP)/
	$t $(MAKE) -C $(APP) -f erlang.mk bootstrap $v

	$i "Add runtime_tools to the list of local dependencies"
	$t perl -ni.bak -e 'print;if ($$.==1) {print "LOCAL_DEPS = runtime_tools\n"}' $(APP)/Makefile

	$i "Build the PLT"
	$t $(DIALYZER_MUTEX) $(MAKE) -C $(APP) plt $v

	$i "Confirm that runtime_tools was included in the PLT"
	$t dialyzer --plt_info --plt $(APP)/.$(APP).plt | grep -q runtime_tools

dialyzer-opts: init

	$i "Bootstrap a new OTP application named $(APP)"
	$t mkdir $(APP)/
	$t cp ../erlang.mk $(APP)/
	$t $(MAKE) -C $(APP) -f erlang.mk bootstrap $v

	$i "Make Dialyzer save output to a file"
	$t perl -ni.bak -e 'print;if ($$.==1) {print "DIALYZER_OPTS = -o output.txt\n"}' $(APP)/Makefile

	$i "Create a module with a function that has no local return"
	$t printf "%s\n" \
		"-module(warn_me)." \
		"-export([doit/0])." \
		"doit() -> gen_tcp:connect(a, b, c), ok." > $(APP)/src/warn_me.erl

	$i "Run Dialyzer"
	$t ! $(DIALYZER_MUTEX) $(MAKE) -C $(APP) dialyze $v

	$i "Check that the PLT file was created"
	$t test -f $(APP)/.$(APP).plt

	$i "Check that the output file was created"
	$t test -f $(APP)/output.txt

dialyzer-plt-apps: init

	$i "Bootstrap a new OTP application named $(APP)"
	$t mkdir $(APP)/
	$t cp ../erlang.mk $(APP)/
	$t $(MAKE) -C $(APP) -f erlang.mk bootstrap $v

	$i "Add runtime_tools to PLT_APPS"
	$t perl -ni.bak -e 'print;if ($$.==1) {print "PLT_APPS = runtime_tools\n"}' $(APP)/Makefile

	$i "Build the PLT"
	$t $(DIALYZER_MUTEX) $(MAKE) -C $(APP) plt $v

	$i "Confirm that runtime_tools was included in the PLT"
	$t dialyzer --plt_info --plt $(APP)/.$(APP).plt | grep -q runtime_tools

dialyzer-plt-ebin-only: init

	$i "Bootstrap a new OTP application named $(APP)"
	$t mkdir $(APP)/
	$t cp ../erlang.mk $(APP)/
	$t $(MAKE) -C $(APP) -f erlang.mk bootstrap $v

	$i "Add Cowlib to the list of dependencies"
	$t perl -ni.bak -e 'print;if ($$.==1) {print "DEPS = cowlib\ndep_cowlib_commit = master\n"}' $(APP)/Makefile

	$i "Build the application"
	$t $(MAKE) -C $(APP) $v

# @todo Temporary measure to make CACHE_DEPS=1 tests work again.
	$i "Patch Cowlib's Erlang.mk"
	$t cp ../erlang.mk $(APP)/deps/cowlib/

	$i "Build Cowlib for tests to fetch autopatched dependencies"
	$t $(MAKE) -C $(APP)/deps/cowlib test-build $v

	$i "Run Dialyzer"
	$t $(DIALYZER_MUTEX) $(MAKE) -C $(APP) dialyze $v

	$i "Check that the PLT file was created"
	$t test -f $(APP)/.$(APP).plt

	$i "Confirm that Cowlib was included in the PLT"
	$t dialyzer --plt_info --plt $(APP)/.$(APP).plt | grep -q cowlib

	$i "Confirm that rebar files were not included in the PLT"
	$t ! dialyzer --plt_info --plt $(APP)/.$(APP).plt | grep -q rebar

dialyzer-plt-swallow-warnings: init

	$i "Bootstrap a new OTP application named $(APP)"
	$t mkdir $(APP)/
	$t cp ../erlang.mk $(APP)/
	$t $(MAKE) -C $(APP) -f erlang.mk bootstrap $v

	$i "Add LFE version referring to a missing function to the list of dependencies"
	$t perl -ni.bak -e 'print;if ($$.==1) {print "DEPS = lfe\ndep_lfe = git https://github.com/rvirding/lfe d656987dc5f5e08306531ad1ce13bf9ca9ec9e5a\n"}' $(APP)/Makefile

	$i "Create the PLT file"
	$t $(DIALYZER_MUTEX) $(MAKE) -C $(APP) plt $v

dialyzer-pt: init

	$i "Bootstrap a new OTP library named $(APP)"
	$t mkdir $(APP)/
	$t cp ../erlang.mk $(APP)/
	$t $(MAKE) -C $(APP) -f erlang.mk bootstrap-lib $v

	$i "Generate a parse_transform module"
	$t printf "%s\n" \
		"-module(my_pt)." \
		"-export([parse_transform/2])." \
		"parse_transform(Forms, _) ->" \
		"	io:format(\"# Running my_pt parse_transform.~n\")," \
		"	Forms." > $(APP)/src/my_pt.erl

	$i "Generate a .erl file that uses the my_pt parse_transform"
	$t printf "%s\n" \
		"-module(my_user)." \
		"-compile({parse_transform, my_pt})." > $(APP)/src/my_user.erl

	$i "Run Dialyzer"
	$t $(DIALYZER_MUTEX) $(MAKE) -C $(APP) dialyze $v
