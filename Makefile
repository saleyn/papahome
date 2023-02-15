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
	mix $@ --quiet

run:
	iex -S mix

.PHONY: test
