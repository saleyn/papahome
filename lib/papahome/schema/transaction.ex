defmodule Papahome.Transaction do
  @moduledoc """
  A transaction schema represents transactions that are either modifications
  of member's balance (e.g. signup credit, addition of minutes) or fulfilled
  member visits by a pal.
  """
  use    TypedEctoSchema
  import Ecto.Changeset
  import Ecto.Query
  alias  Papahome.Repo
  alias  Papahome.{User, Visit}

  typed_schema "transaction" do
    belongs_to :member,       User,     null: false
    belongs_to :pal,          User
    belongs_to :visit,        Visit
    field      :description,  :string
    field      :minutes,      :integer, null: false
    field      :fee_minutes,  :integer, null: false
    field      :visited_at,   :utc_datetime

    timestamps()
  end

  ##----------------------------------------------------------------------------
  ## Public API
  ##----------------------------------------------------------------------------

  def changeset(%__MODULE__{} = transaction, params \\ %{}) do
    transaction
    |> cast(params,      [:member_id,   :pal_id, :visit_id, :description, :minutes,
                          :fee_minutes, :visited_at])
    |> validate_required([:member_id, :minutes, :fee_minutes])
  end

  @doc "Record a signup credit for a given member"
  def signup_credit(%User{} = member), do:
    add_minutes(member, "signup credit", member.balance_minutes)

  @doc "Add minutes to a given member"
  def add_minutes(%User{} = member, minutes), do:
    add_minutes(member, "added minutes", minutes)

  @doc "List all transactions for a given member"
  def list_for_member(member_id) do
    from(t in __MODULE__,
      where: t.member_id == ^member_id,
      order_by: [desc: t.inserted_at]
    )
    |> preload([:member, :pal, :visit])
    |> Repo.all()
  end

  @doc "List all transactions for a given member"
  def list_for_pal(pal_id) do
    from(t in __MODULE__,
      where:    t.pal_id == ^pal_id,
      order_by: [desc: t.inserted_at]
    )
    |> preload([:member, :pal, :visit])
    |> Repo.all()
  end

  ##----------------------------------------------------------------------------
  ## Internal functions
  ##----------------------------------------------------------------------------

  defp add_minutes(%User{is_member: true} = member, text, minutes)
  when is_integer(minutes) and minutes > 0
  do
    %__MODULE__{}
    |> changeset(%{
        member_id:  member.id, description: text,
        minutes:    minutes,   fee_minutes: 0
      })
    |> Repo.insert()
  end
end
