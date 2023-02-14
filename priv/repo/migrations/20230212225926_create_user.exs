defmodule Papahome.Repo.Migrations.CreateUser do
  use Ecto.Migration

  def change do
    create table(:user) do
      add :email,           :string,   null:    false
      add :first_name,      :string,   null:    false
      add :last_name,       :string,   null:    false
      add :is_member,       :boolean,  default: false
      add :is_pal,          :boolean,  default: false
      add :balance_minutes, :integer,  null:    false,
        comment: "Current user's balance of minutes"

      timestamps()
    end

    create unique_index(:user, [:email])
  end
end
