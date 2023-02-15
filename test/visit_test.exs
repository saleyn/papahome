defmodule Papahome.VisitTest do
  use     Papahome.RepoCase

  setup_all do
    {:ok, %User{id: id1, balance_minutes: 100}} = Factory.create_member()
    {:ok, %User{id: id2, balance_minutes:   0}} = Factory.create_pal()
    {:ok, %User{id: id3, balance_minutes: 100}} = Factory.create_pal_member()

    on_exit(fn -> Factory.delete_users([id1, id2, id3]) end)
    :ok
  end

  describe "Create visit" do
    setup do
      {:ok, %Visit{minutes: 60}} = Visit.create("benny@gmail.com", 60, date())
      :ok
    end

    test "succeeds for a member that has enough balance" do
      %User{id: id} = user = User.find("benny@gmail.com")
      assert     60 = User.requested_minutes(id)

      # Check that the member only has 40 minutes left
      assert     40 = User.available_minutes(user)
    end

    test "fails for a member that doesn't have enough balance" do
      assert {:error, "member doesn't have enough minutes in the balance"} =
        Visit.create("benny@gmail.com", 60, date())
    end

    test "succeeds when :max minutes are requested" do
      assert {:ok, %Visit{minutes: 40}} =
        Visit.create("benny@gmail.com", :max, date())
    end
  end

  describe "Fulfill visit" do
    setup do
      # Create 3 visits inserted at 1s apart to guarantee the sorting order
      date = date() |> DateTime.add(1, :day)
      {:ok, %Visit{minutes: 60}} = Visit.create("benny@gmail.com", 60,   date, ["companionship"])
      Process.sleep(1000)
      {:ok, %Visit{minutes: 40}} = Visit.create("benny@gmail.com", :max, date, ["conversation"])
      Process.sleep(1000)
      {:ok, %Visit{minutes: 50}} = Visit.create("alice@gmail.com", 50,   date, ["walking"])

      %{date: date}
    end

    test "ensure that three visits are requested" do
      assert 3 == date() |> Visit.list_available() |> Enum.count()
    end

    test "fails when requested by a non-member and non-pal" do
      assert {:error, "user must be a pal in order to fulfill a visit"} =
        Visit.fulfill("incognito@gmail.com")
    end

    test "fails when requested by a member" do
      assert {:error, "user must be a pal in order to fulfill a visit"} =
        Visit.fulfill("benny@gmail.com")
    end

    test "succeeds by a pal", %{date: expected_date} do
      assert {:ok, %Transaction{minutes: 51, fee_minutes: 9}} =
        Visit.fulfill("alex@gmail.com")

      # Check that the member's and pal's balances are updated
      assert %User{balance_minutes: 40} = User.find("benny@gmail.com")
      assert %User{balance_minutes: 51} = User.find("alex@gmail.com")

      date = date() |> DateTime.truncate(:second)

      assert {:ok, %Transaction{minutes: 34, fee_minutes: 6, visited_at: ^expected_date}} =
        Visit.fulfill("alex@gmail.com", date)

      # Check that the member's and pal's balances are updated
      assert %User{balance_minutes:  0} = User.find("benny@gmail.com")
      assert %User{balance_minutes: 85} = User.find("alex@gmail.com")

      # One more visit requested
      assert 1 == date() |> Visit.list_available() |> Enum.count()

      # Alice's own visit requests are not seen by Alice
      alice_user_id = User.find("alice@gmail.com").id
      assert 0 == date() |> Visit.list_available(alice_user_id) |> Enum.count()

      # The remaining visit is requested by alice, but she cannot see/fulfill
      # her own visits
      assert {:error, "no visits available at this time"} =
        Visit.fulfill("alice@gmail.com")

      # But a pal Alex can fulfill Alice's visit
      assert {:ok, %Transaction{minutes:     43,
                                fee_minutes: 7,
                                member_id:   ^alice_user_id,
                                visited_at:  ^expected_date}} =
        Visit.fulfill("alex@gmail.com", date)

      # No more visits requested
      assert 0 == date() |> Visit.list_available() |> Enum.count()

      assert {:error, "no visits available at this time"} =
        Visit.fulfill("alex@gmail.com")
    end
  end

  defp date(), do: DateTime.utc_now() |> DateTime.add(1, :day) |> DateTime.truncate(:second)
end
