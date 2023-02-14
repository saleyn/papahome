defmodule Papahome.User do
  @moduledoc """
  A user schema containing user details that include user roles (member/pal) and
  user account balance.
  """
  use    TypedEctoSchema
  import Ecto.Changeset
  import Ecto.Query
  alias  Ecto.Multi
  alias  Papahome.{Repo, Visit, Transaction}

  typed_schema "user" do
    field      :email,           :string
    field      :first_name,      :string
    field      :last_name,       :string
    field      :is_member,       :boolean, default: false
    field      :is_pal,          :boolean, default: false
    field      :balance_minutes, :integer, default: 0

    timestamps()
  end

  @signup_member_credit Application.compile_env(:papahome, :signup_member_credit)

  ##----------------------------------------------------------------------------
  ## Public API
  ##----------------------------------------------------------------------------

  def changeset(%__MODULE__{} = user, params \\ %{}) do
    user
    |> cast(params,      [:email, :first_name, :last_name, :is_member, :is_pal, :balance_minutes])
    |> validate_required([:email, :first_name, :last_name])
    |> validate_email()
    |> unique_constraint([:email])
    |> validate_member_or_pal()        # A user must be either a member or a pal or both
  end

  defp validate_member_or_pal(changeset) do
    if get_field(changeset, :is_member) or get_field(changeset, :is_pal) do
      changeset
    else
      add_error(changeset, :is_member, "A user must be a member or a pal")
    end
  end

  defp validate_email(changeset) do
    email = get_field(changeset, :email)
    if Regex.match?(~r/^[A-Za-z0-9\._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,6}$/, email) do
      changeset
    else
      add_error(changeset, :email, "invalid email")
    end
  end

  @doc """
  Create a user record.

  If this user is a member, add a signup credit to the member's balance, and
  also record the credit in the transaction table.
  """
  @spec create(map) :: {:ok, t} | {:error, any}
  def   create(attrs) do
    Multi.new()
    ## (1) insert a user record, and if it's a member, add signup credit
    |> Multi.run(:user, fn _repo, _cset ->
      %__MODULE__{}
      |> changeset(attrs)
      |> then(fn cs ->
        if get_field(cs, :is_member) do
          add_member_signup_credit(cs)
        else
          cs
        end
      end)
      |> Repo.insert()
    end)
    ## (2) if a member was issued a signup credit, record that in the transaction table
    |> Multi.run(:signup_credit, fn _repo, %{user: user} ->
      if user.is_member do
        Transaction.signup_credit(user)
      else
        {:ok, user}
      end
    end)
    |> Repo.transaction()
    |> case do
      {:ok,    %{user: user}}         -> {:ok,    user}
      {:error, :user,  changeset,  _} -> {:error, changeset}
      {:error, _name,  err, _changes} -> {:error, err}
    end
  end

  @doc "Update a user record"
  def update(%__MODULE__{} = user, attrs \\ %{}) do
    user
    |> changeset(attrs)
    |> Repo.update()
  end

  @doc "List all users"
  def list() do
    from(u in __MODULE__) |> Repo.all()
  end

  @doc "Get user by ID"
  @spec get(integer) :: t | nil
  def   get(user_id) when is_integer(user_id) do
    Repo.get(__MODULE__, user_id)
  end

  @doc "Query user by email"
  @spec find(String.t) :: t | nil
  def   find(email) when is_binary(email) do
    Repo.get_by(__MODULE__, email: email)
  end

  @doc "Check if a user is a member"
  @spec is_member?(String.t) :: boolean
  def   is_member?(email) do
    user = find(email)
    user && user.is_member
  end

  @doc "Check if a user is a pal"
  @spec is_pal?(String.t) :: boolean
  def   is_pal?(email) do
    user = find(email)
    user && user.is_pal
  end

  @doc """
  Add minutes to a member's balance.

  If this user is a member, add a signup credit to the member's balance, and
  also record the credit in the transaction table.
  """
  def add_minutes(member_email, minutes) when is_integer(minutes) and minutes > 0 do
    Multi.new()
    ## (1) add balance to the member's record
    |> Multi.run(:user, fn _repo, _changes ->
      case find(member_email) do
        %__MODULE__{is_member: true, balance_minutes: curr_minutes} = user ->
          changeset(user, %{balance_minutes: curr_minutes + minutes})
          |> Repo.update()
        %__MODULE__{is_member: false} ->
          {:error, "user must be a member"}
        nil ->
          {:error, "unknown member"}
      end
    end)
    ## (2) record the event in the transaction table
    |> Multi.run(:signup_credit, fn _repo, %{user: user} ->
      Transaction.add_minutes(user, minutes)
    end)
    |> Repo.transaction()
    |> case do
      {:ok,    %{user: user}}         -> {:ok,    user}
      {:error, :user,  changeset,  _} -> {:error, changeset}
      {:error, _name,  err, _changes} -> {:error, err}
    end
  end

  @doc "Get the number of requested minutes for a given member"
  def   requested_minutes(member_id) when is_integer(member_id) do
    from(v in Visit,
      where:  v.member_id == ^member_id and is_nil(v.pal_id),
      select: sum(v.minutes))
    |> Repo.one() || 0
  end

  @doc "Get the number of available minutes for a given member"
  def   available_minutes(%__MODULE__{is_member: true, balance_minutes: balance} = member) do
    max(0, balance - requested_minutes(member.id))
  end

  ##----------------------------------------------------------------------------
  ## Internal functions
  ##----------------------------------------------------------------------------

  ## If this is a member and no balance_minutes were set, add signup minutes credit
  defp add_member_signup_credit(changeset) do
    with \
      true  <- get_field(changeset, :is_member),
      0     <- get_field(changeset, :balance_minutes)
    do
      put_change(changeset, :balance_minutes, @signup_member_credit)
    else
      false ->
        add_error(changeset, :is_member, "A user must be a member in order to receive signup credit")
      n when is_integer(n) and n > 0 ->
        add_error(changeset, :is_member, "A member cannot receive free credit if balance is not 0")
      nil ->
        add_error(changeset, :balance_minutes, "Invalid nil balance")
    end
  end

end
