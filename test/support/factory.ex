defmodule Papahome.Test.Factory do
  @moduledoc """
  Some helpter functions to create/delete users
  """
  alias Papahome.{Repo, User}

  def create_member(), do:
    User.create(%{email: "benny@gmail.com", first_name: "Ben", last_name: "Worth", is_member: true})

  def create_pal(), do:
    User.create(%{email: "alex@gmail.com", first_name: "Alex", last_name: "Moore", is_pal: true})

  def delete_users(users) do
    Enum.each(users, & User.get(&1) |> Repo.delete)
  end
end
