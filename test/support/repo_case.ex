defmodule Papahome.RepoCase do
  @moduledoc """
  A template used for building test cases that support Ecto Sanbox isolation
  """
  use   ExUnit.CaseTemplate
  alias Ecto.Adapters.SQL.Sandbox

  using do
    quote do
      import Papahome.RepoCase
      alias  Papahome.{Repo, Transaction, User, Visit}
      alias  Papahome.Test.Factory
    end
  end

  setup do
    :ok = Sandbox.checkout(Papahome.Repo)
  end
end
