defmodule Papahome.VisitTest do
  use     Papahome.RepoCase

  setup_all do
    {:ok, %User{id: id1, balance_minutes: 100}} = Factory.create_member()
    {:ok, %User{id: id2, balance_minutes:   0}} = Factory.create_pal()

    on_exit(fn -> Factory.delete_users([id1, id2]) end)
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
      # Create 2 visits
      {:ok, %Visit{minutes: 60}} = Visit.create("benny@gmail.com", 60,   date(), ["companionship"])
      {:ok, %Visit{minutes: 40}} = Visit.create("benny@gmail.com", :max, date(), ["conversation"])
      :ok
    end

    test "ensure that two visits are requested" do
      assert 2 == date() |> Visit.list_available() |> Enum.count()
    end

    test "fails when requested by a non-member and non-pal" do
      assert {:error, "user must be a pal in order to fulfill a visit"} =
        Visit.fulfill("incognito@gmail.com")
    end

    test "fails when requested by a member" do
      assert {:error, "user must be a pal in order to fulfill a visit"} =
        Visit.fulfill("benny@gmail.com")
    end

    test "succeeds by a pal" do
      assert {:ok, %Transaction{minutes: 51, fee_minutes: 9}} =
        Visit.fulfill("alex@gmail.com")

      # Check that the member's and pal's balances are updated
      assert %User{balance_minutes: 40} = User.find("benny@gmail.com")
      assert %User{balance_minutes: 51} = User.find("alex@gmail.com")

      date = date() |> DateTime.truncate(:second)

      assert {:ok, %Transaction{minutes: 34, fee_minutes: 6, fulfilled_at: ^date}} =
        Visit.fulfill("alex@gmail.com", date)

      # Check that the member's and pal's balances are updated
      assert %User{balance_minutes:  0} = User.find("benny@gmail.com")
      assert %User{balance_minutes: 85} = User.find("alex@gmail.com")

      # No more visits requested
      assert 0 == date() |> Visit.list_available() |> Enum.count()

      assert {:error, "no visits available at this time"} =
        Visit.fulfill("alex@gmail.com")
    end
  end

  defp date(), do: DateTime.utc_now() |> DateTime.add(1, :day)
end
