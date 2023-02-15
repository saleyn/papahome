defmodule Papahome.Visit do
  @moduledoc """
  A visit schema contains visit requests by members and if pal_id is defined on
  a visit record, that means that the visit is fulfilled by a pal.
  """
  use    TypedEctoSchema
  import Ecto.Changeset
  import Ecto.Query
  alias  Ecto.Multi
  alias  Papahome.{Repo, User, Transaction}

  typed_schema "visit" do
    belongs_to :member,       User,              null: false
    field      :date,         :utc_datetime,     null: false
    field      :minutes,      :integer,          null: false
    field      :tasks,        {:array, :string}, null: false, default: []

    belongs_to :pal,          User
    has_one    :transaction,  Transaction

    timestamps()
  end

  @fee_overhead Application.compile_env(:papahome, :fee_overhead)

  ##----------------------------------------------------------------------------
  ## Public API
  ##----------------------------------------------------------------------------

  def changeset(%__MODULE__{} = visit, attrs \\ %{}) do
    visit
    |> cast(attrs,       [:member_id, :pal_id, :date, :minutes, :tasks])
    |> validate_required([:member_id, :date, :minutes, :tasks])
  end

  @doc "Update a visit record with a pal as part of the fulfillment"
  def update(%__MODULE__{} = visit, attrs) do
    visit
    |> cast(attrs,       [:pal_id])
    |> validate_required([:pal_id])
  end

  @doc """
  List available visits requested by members that haven't been fulfilled by pals.

  If this call is passed a `pal_id` (i.e. it's made by a pal who's incuiring
  about available visits), it's assumed that a pal cannot see/fulfill his own
  visit requests if he's also a member.
  """
  def list_available(%DateTime{} = as_of_date \\ DateTime.utc_now(), pal_id \\ nil) do
    # If pal_id is given, filter out matching member_id records
    filter_out_pal_id = pal_id && dynamic([v], v.member_id != ^pal_id) || true

    from(v in __MODULE__,
      where:    is_nil(v.pal_id) and v.date >= ^as_of_date,
      where:    ^filter_out_pal_id,
      order_by: v.inserted_at,
      preload:  [:member]
    )
    |> Repo.all()
  end

  @doc """
  Get the next available visit

  If this call is passed a `pal_id` (i.e. it's made by a pal who's incuiring
  about available visits), it's assumed that a pal cannot see/fulfill his own
  visit requests if he's also a member.
  """
  def next_available(%DateTime{} = as_of_date \\ DateTime.utc_now(), pal_id \\ nil) do
    # If pal_id is given, filter out matching member_id records
    filter_out_pal_id = pal_id && dynamic([v], v.member_id != ^pal_id) || true

    from(v in __MODULE__,
      where:    is_nil(v.pal_id) and v.date >= ^as_of_date,
      where:    ^filter_out_pal_id,
      order_by: [v.inserted_at, v.date],
      limit:    1,
      preload:  [:member]
    )
    |> Repo.one()
  end

  @doc """
  Create a new visit request.

  Such a request can only be created by a member. A request can only be created
  for a future date.  The member must have enough minutes balance (less the
  minutes of already requested visits).

  If a member requests `:max` minutes, a visit request will be created for all
  of the member's available minutes.
  """
  @spec create(String.t, :max | integer, DateTime.t, [String.t]) ::
          {:ok, t} | {:error, any()}
  def   create(member_email, minutes, %DateTime{} = date, tasks \\ [])
  when  is_binary(member_email) and (is_integer(minutes) or minutes == :max) and
        is_list(tasks)
  do
    attrs = %{date: date, minutes: minutes, tasks: tasks}
    now   =  DateTime.utc_now()

    case DateTime.compare(date, now) do
      :lt ->
        {:error, "visit date must be in the future"}
      _ ->
        Multi.new()
        ## (1) Make sure only a member can request a visit
        |> Multi.run(:member, fn _repo, _ctx ->
          case User.find(member_email) do
            %User{is_member: true} = user ->
              {:ok, user}
            _ ->
              {:error, "user must be an existing member"}
          end
        end)
        ## (2) Make sure the member has enough minutes to schedule a request
        |> Multi.run(:minutes, fn _repo, %{member: member} ->
          remaining_minutes = User.available_minutes(member)
          case minutes do
            n when is_integer(n) and n > 0 and n <= remaining_minutes ->
              {:ok, n}
            :max when remaining_minutes > 0 ->
              {:ok, remaining_minutes}
            _ ->
              {:error, "member doesn't have enough minutes in the balance"}
          end
        end)
        ## (3) Insert the new visit record for the given number of minutes
        |> Multi.insert(:visit, fn %{member: member, minutes: _minutes} = changes ->
          attrs = Map.merge(attrs, changes) |> Map.put(:member_id, member.id)
          changeset(%__MODULE__{}, attrs)
        end)
        |> Repo.transaction()
        |> case do
          {:ok, %{visit: visit}}   -> {:ok,    visit}
          {:error, _key, value, _} -> {:error, value}
        end
    end
  end

  @doc """
  Fulfill a visit request.

  This can only be done by a pal, who requests to fulfill a visit from a given
  date onward.
  """
  @spec fulfill(String.t, DateTime.t) :: {:ok, Transaction.t} | {:error, any}
  def   fulfill(pal_email, %DateTime{} = as_of_date \\ DateTime.utc_now()) do
    Multi.new()
    ## (1) check that the `pal_email` is a valid pal
    |> Multi.run(:pal, fn _repo, _changes ->
      case User.find(pal_email) do
        %User{is_pal: true} = pal ->
          {:ok, pal}
        _ ->
          {:error, "user must be a pal in order to fulfill a visit"}
      end
    end)
    ## (2) get the next available visit request
    |> Multi.run(:visit, fn _repo, %{pal: %{id: pal_id}} ->
      case next_available(as_of_date, pal_id) do
        %__MODULE__{} = visit -> {:ok, visit}
        nil                   -> {:error, "no visits available at this time"}
      end
    end)
    ## (3) calculate the minites credit/debit/fee
    |> Multi.run(:minutes, fn _repo, %{visit: visit} ->
      debit  = visit.member.balance_minutes - visit.minutes
      credit = round(visit.minutes * (1 - @fee_overhead))
      fee    = visit.minutes - credit
      {:ok, %{debit: debit, credit: credit, fee: fee}}
    end)
    ## (4) assign the pal to this visit
    |> Multi.update(:pal_visit, fn %{pal: pal, visit: visit} ->
      changeset(visit, %{pal_id: pal.id})
    end)
    ## (5) debit the member's balance for this visit
    |> Multi.update(:member_balance, fn %{visit: visit, minutes: %{debit: debit}} ->
      User.changeset(visit.member, %{balance_minutes: debit})
    end)
    ## (6) credit the pal's balance for this visit
    |> Multi.update(:pal_balance, fn %{pal: pal, minutes: %{credit: credit}} ->
      User.changeset(pal, %{balance_minutes: pal.balance_minutes + credit})
    end)
    ## (7) insert a transaction for this visit
    |> Multi.insert(:transaction, fn %{pal: pal, visit: visit, minutes: %{credit: credit, fee: fee}} ->
      params = %{
        description:  "fulfillment",
        minutes:      credit,
        fee_minutes:  fee,
        visited_at:   visit.date,
        member_id:    visit.member.id,
        pal_id:       pal.id,
        visit_id:     visit.id,
      }
      Transaction.changeset(%Transaction{}, params)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{transaction: txn}} -> {:ok,    txn}
      {:error, _key, why,     _} -> {:error, why}
    end
  end
end
