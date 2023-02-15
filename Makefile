all: compile dialyzer escriptize

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

dialyzer:
	@[ "${MIX_ENV}" == "dev" -o -z "${MIX_ENV}" ] && echo "Running Dialyzer" && mix $@ --quiet || true

run:
	iex -S mix

distclean:
	rm -fr _build deps papahome

.PHONY: test
