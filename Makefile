all: compile static-check escriptize

compile: deps
	mix $@

escriptize:
	mix escript.build

deps:
	mix deps.get

bootstrap:
	mix ecto.reset

test:
	mix $@

static-check:
	@if [ "${MIX_ENV}" == "dev" -o -z "${MIX_ENV}" ]; then \
   echo "Running dializer" && mix dialyzer --quiet; \
  echo "Running credo"    && mix credo --strict; \
	fi

run:
	iex -S mix

distclean:
	rm -fr _build deps papahome

.PHONY: test
