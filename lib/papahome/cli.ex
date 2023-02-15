defmodule Papahome.CLI do
  @moduledoc """
  Command-line interface functions for working with the Papa Home Visit system.

  This CLI is invokable directly from a Linux shell.

  ## Example

    $ ./papahome help

  """
  alias Papahome.{User, Visit, Transaction}

  @spec main([binary]) :: :ok | no_return
  def main([help]) when help in ["-h", "--help", "help"] do
    IO.puts("""
    #{:escript.script_name} Options

    This script is the CLI for the Papa Home Visit system.

    To customize the database login, export the following environment variables:

      "DB_NAME" - database name
      "DB_USER" - database user
      "DB_PASS" - user's password
      "DB_HOST" - database host

    Below is the list of supported commands:

    Options:
    ========

    help | -h | --help
      - Print this help screen

    create [member|pal|pal-member|member-pal] Email --first-name=First --last-name=Last [--balance=NNN]
      - Create a member, a pal or both

        Example: "create member some@email.com --first-name=Alex --last-name=Brown"

    create visit MemberEmail --minutes=Minutes [--date=VisitDate] [--task=Tasks]
      - Create a visit request by a member identified by MemberEmail. Minutes
        can be an integer or "max" for all available minutes.  If date is not
        specified, it defaults to tomorrow.  Tasks can be a comma-delimited list
        of tasks.

        Example: "create visit some@email.com --minutes=100 --date='2023-06-08 19:00:00'"

    fulfill visit PalEmail [--date=AsOfDate]
      - Try to fulfill a visit by a pal. Optionally provide a date filter to only
        consider visits on or after AsOfDate.

        Example: "fulfill visit pal@email.com"

    user Email
      - Get user's information and balance

    list users
      - List registered users

    list visits
      - List requested visits

    list [member|pal] transactions Email
      - List transactions for a given member/pal email

    add minutes MemberEmail Minutes
      - Add minutes to a member

        Example: "add minutes some@email.com 100"
    """)
  end

  def main(options) do
    try do
      parse(options)
    rescue err ->
      IO.puts("ERROR: #{Exception.message(err)}")
      IO.puts("  Stack:")
      Exception.format_stacktrace(__STACKTRACE__) |> IO.puts()
      System.halt(1)
    end
  end

  ##----------------------------------------------------------------------------
  ## Internal functions
  ##----------------------------------------------------------------------------

  ## Create a member/pal
  defp parse(["create", user, email | rest]) when user in ["member", "pal", "pal-member", "member-pal"] do
    opts = [first_name: :string, last_name: :string, balance_minutes: :integer]
    case OptionParser.parse(rest, strict: opts) do
      {attrs, [], []} ->
        balance = Keyword.get(attrs, :balance) || 0
        attrs =
          attrs
          |> Keyword.put(:email,           email)
          |> Keyword.put(:is_member,       user in ["member", "pal-member", "member-pal"])
          |> Keyword.put(:is_pal,          user in ["pal",    "pal-member", "member-pal"])
          |> Keyword.put(:balance_minutes, balance)
          |> Enum.into(%{})

        case User.create(attrs) do
          {:ok, %User{id: id}} ->
            IO.puts("Created #{user} ID=#{id}")
          {:error, error} ->
            raise error(error)
        end
      {_, args, unknown} ->
        help("invalid options", args, unknown)
    end
  end

  ## Create a visit for a member
  defp parse(["create", "visit", email | rest]) do
    opts = [minutes: :string, date: :string, task: :string]
    case OptionParser.parse(rest, strict: opts) do
      {attrs, [], []} ->
        minutes = Keyword.get(attrs, :minutes) |> parse_minutes_or_max("invalid minutes")
        date    = Keyword.get(attrs, :date)    |> parse_date("invalid date") ||
                    (DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.add(1, :day))
        tasks   = (Keyword.get(attrs, :task) || "") |> String.split(",", trim: true)

        case Visit.create(email, minutes, date, tasks) do
          {:ok, %Visit{id: id}} ->
            IO.puts("Created visit for member #{email}: ID=#{id}")
          {:error, error} ->
            raise error(error)
        end
      {_, args, unknown} ->
        help("invalid options", args, unknown)
    end
  end

  ## Fulfil a visit by pal
  defp parse(["fulfill", "visit", pal_email | rest]) do
    case OptionParser.parse(rest, strict: [date: :string]) do
      {attrs, [], []} ->
        date = Keyword.get(attrs, :date) |> parse_date("invalid date") ||
                (DateTime.utc_now() |> DateTime.truncate(:second))

        case Visit.fulfill(pal_email, date) do
          {:ok, %Transaction{id: id, minutes: minutes, fee_minutes: fee}} ->
            IO.puts("Visit fulfilled by pal #{pal_email}: TxnID=#{id} Minutes=#{minutes} Fee=#{fee}")
          {:error, error} ->
            raise error(error)
        end
      {_, args, unknown} ->
        help("invalid options", args, unknown)
    end
  end

  ## Get user information
  defp parse(["user", email]) do
    case User.find(email) do
      %User{id: id, first_name: first, last_name: last,
            is_member: mem, is_pal: pal, balance_minutes: minutes} ->
        IO.puts("""
          User:     #{first} #{last} <#{email}>
          UserID:   #{id}
          IsMember: #{mem}
          IsPal:    #{pal}
          Balance:  #{minutes}
          """)
      nil ->
        raise "user #{email} not found"
    end
  end

  ## List transacations for a given email
  defp parse(["list", role, "transactions", email]) when role in ["member", "pal"] do
    case User.find(email) do
      %User{id: id, is_member: true} when role == "member" ->
        Transaction.list_for_member(id) |> print_transactions()
      %User{id: id, is_pal:    true} when role == "pal" ->
        Transaction.list_for_pal(id)    |> print_transactions()
      %User{} ->
        raise "user #{email} is not a #{role}"
      nil ->
        raise "user #{email} not found"
    end
  end

  ## List all users
  defp parse(["list", "users"]) do
    IO.puts("#{pad("ID", 9)} | #{pad("Email", 20)} | #{pad("FirstName",20)} | #{pad("LastName",20)} | Mem | Pal | Balance")
    IO.puts("#{sep(9)}-+-#{sep(20)}-+-#{sep(20)}-+-#{sep(20)}-+-----+-----+--------")
    User.list()
    |> Enum.each(fn %User{id: id, email: email, first_name: first, last_name: last,
                          is_member: mem, is_pal: pal, balance_minutes: balance} ->
        IO.puts("#{pad(id, 9)} | #{pad(email, 20)} | #{pad(first,20)} | #{pad(last,20)} | " <>
                "#{mem && " x " || "   "} | #{pal && " x " || "   "} | #{balance}")
      end)
  end

  ## List all visits
  defp parse(["list", "visits"]) do
    IO.puts("#{pad("ID", 9)} | #{pad("Date", 20)} | #{pad("Minutes",20)} | #{pad("Member",30)} | Tasks")
    IO.puts("#{sep(9)}-+-#{sep(20)}-+-#{sep(20)}-+-#{sep(30)}-+-------------")
    Visit.list_available()
    |> Enum.each(fn %Visit{id: id, member: %{email: mem}, date: date, minutes: minutes, tasks: tasks} ->
        date = date |> DateTime.truncate(:second) |> DateTime.to_string()
        IO.puts("#{pad(id, 9)} | #{date} | #{pad(minutes,20)} | #{pad(mem,30)} | #{Enum.join(tasks, ",")}")
      end)
  end

  ## Add minutes to a member
  defp parse(["add", "minutes", email, minutes]) do
    minutes =
      case Integer.parse(minutes) do
        {n, ""} when n > 0 -> n
        _                  -> raise "minutes must be an integer > 0"
      end
    case User.add_minutes(email, minutes) do
      {:ok, %User{balance_minutes: balance}} ->
        IO.puts("added #{minutes} to member: balance=#{balance}")
      {:error, error} ->
        error(error)
    end
  end

  defp parse([]),    do: help("missing required options", "type: #{:escript.script_name} help")
  defp parse(other), do: help("invalid options",          other)

  @spec help(String.t, list|String.t) :: no_return
  defp help(prefix, args),        do: help(prefix, args, [])
  defp help(prefix, unknown, []), do: raise prefix <> ": #{inspect(unknown)}"
  defp help(prefix, [], unknown), do: raise prefix <> ": #{inspect(unknown)}"

  @spec error(Ecto.Changeset.t) :: no_return
  defp error(%Ecto.Changeset{} = changeset) do
    error = Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
    error(error)
  end

  defp error(text) when is_binary(text) do
    IO.puts("ERROR: #{text}")
    System.halt(1)
  end

  defp parse_date(nil, _error_text), do: nil
  defp parse_date(date, error_text)  do
    case DateTime.from_iso8601(date <> "Z") do
      {:ok, date, _} ->
        date
      {:error, _} ->
        raise error_text <> ": #{date}"
    end
  end

  defp parse_minutes_or_max(nil,   _err_text), do: nil
  defp parse_minutes_or_max("max", _err_text), do: :max
  defp parse_minutes_or_max(value,  err_text)  do
    case Integer.parse(value) do
      {n, ""} -> n
      _       -> raise err_text <> ": #{value}"
    end
  end

  defp print_transactions(txns) do
    IO.puts("#{pad("ID", 9)} | #{pad("VisitDate", 20)} | #{pad("Member", 20)} | #{pad("Pal", 20)} | Minutes | Fee   | Description")
    IO.puts("#{sep(9)}-+-#{sep(20)}-+-#{sep(20)}-+-#{sep(20)}-+---------+-------+#{sep(12)}")
    Enum.each(txns, &print_txn(&1))
  end

  defp print_txn(%Transaction{
    id:         id,   member:  %User{email: member}, pal: pal,
    visited_at: date, minutes: minutes, fee_minutes: fee, description: descr
  }) do
    date = date && date |> DateTime.truncate(:second) |> DateTime.to_string()
    pal  = pal  && pal.email
    IO.puts("#{pad(id, 9)} | #{pad(date, 20)} | #{pad(member, 20)} | #{pad(pal, 20)} | #{pad(minutes, 7)} | #{pad(fee, 5)} | #{descr}")
  end

  defp pad(str, len) when is_binary(str), do: String.pad_trailing(str, len)
  defp pad(nil, len),                     do: String.pad_trailing("", len)
  defp pad(str, len),                     do: inspect(str) |> String.pad_trailing(len)
  defp sep(len),                          do: String.pad_trailing("", len, "-")

end
