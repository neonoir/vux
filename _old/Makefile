.PHONY: all deps compile clean distclean shell

DEPS_DIR = $(CURDIR)/deps
RABBIT_DL_URI = http://www.rabbitmq.com/releases/rabbitmq-erlang-client/v3.2.3
RABBIT = $(DEPS_DIR)
DEPS = $(RABBIT)/rabbit_common-3.2.3.ez \
       $(RABBIT)/amqp_client-3.2.3.ez

all: deps compile

deps: $(DEPS_DIR) $(DEPS)

$(DEPS_DIR):
	mkdir -p $(DEPS_DIR)

$(RABBIT)%:
	wget $(RABBIT_DL_URI)$* -O $@
	unzip $@ -d $(DEPS_DIR)

compile:
	erl -pa deps/*/ebin -make

clean:
	rm -rf *.beam ebin/*.beam erl_crash.dump

distclean: clean
	rm -rf $(DEPS_DIR)

shell:
	erl -pa ebin deps/*/ebin -s reloader start
