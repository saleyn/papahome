defmodule Papahome.RepoCase do
  @moduledoc """
  A template used for building test cases that support Ecto Sanbox isolation
  """
  use ExUnit.CaseTemplate

  using do
    quote do
      import Papahome.RepoCase
      alias  Papahome.{Repo, User, Visit, Transaction}
      alias  Papahome.Test.Factory
    end
  end

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Papahome.Repo)
  end
end
