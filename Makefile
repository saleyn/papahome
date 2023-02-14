all: compile escriptize

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

run:
	iex -S mix
