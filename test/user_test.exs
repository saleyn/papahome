defmodule Papahome.UserTest do
  use     Papahome.RepoCase

  @signup_credit Application.compile_env(:papahome, :signup_member_credit)

  describe "Creating user" do
    test "succeeds when user is a member with a signup credit" do
      assert {:ok, %User{
        id:              id,
        email:           "benny@gmail.com",
        first_name:      "Ben",
        last_name:       "Worth",
        is_member:       true,
        is_pal:          false,
        balance_minutes: @signup_credit,
      }} = Factory.create_member()

      assert [%Transaction{
        description:     "signup credit",
        fee_minutes:     0,
        minutes:         100,
      }] = Transaction.list_for_member(id)
    end

    test "succeeds when user is a pal" do
      assert {:ok, %User{
        email:           "alex@gmail.com",
        first_name:      "Alex",
        last_name:       "Moore",
        is_member:       false,
        is_pal:          true,
        balance_minutes: 0,
      }} = Factory.create_pal()
    end

    test "succeeds when user is a pal and a member" do
      assert {:ok, %User{
        is_member:       true,
        is_pal:          true,
        balance_minutes: 100,
      }} = Factory.create_pal_member()
    end

    test "succeeds to look up a user" do
      assert {:ok, %User{id: user_id}} = Factory.create_member()
      assert %User{id: id} = User.find("benny@gmail.com")
      assert %User{}       = User.get(id)
      assert id           == user_id
    end

    test "fails when user has a duplicate email" do
      assert {:ok, %User{}} = Factory.create_member()

      assert {:error, %Ecto.Changeset{errors: [email: {"has already been taken", _}]}} =
        Factory.create_member()
    end

    test "fails when user is not a member and not a pal" do
      assert {:error, %Ecto.Changeset{errors: [is_member: {"A user must be a member or a pal", _}]}} =
        User.create(
          %{email: "some@gmail.com", first_name: "First", last_name: "Last"}
        )
    end
  end

  test "added minutes to member reflected in transactions" do
    assert {:ok, %User{balance_minutes: 100, id: id}} = Factory.create_member()
    assert {:ok, %User{balance_minutes: 150}}         = User.add_minutes("benny@gmail.com", 50)

    assert [
      %Transaction{
        description: "signup credit",
        fee_minutes: 0,
        minutes:     100,
      },
      %Transaction{
        description: "added minutes",
        fee_minutes: 0,
        minutes:     50,
      },
    ] = Transaction.list_for_member(id)
  end
end
