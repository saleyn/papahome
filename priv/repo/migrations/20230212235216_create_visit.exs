defmodule Papahome.Repo.Migrations.CreateVisit do
  use Ecto.Migration

  def change do
    create table(:visit,   comment: "Defines a visit requested by a member") do
      add :member_id,      references(:user,  on_delete: :delete_all), null: false, comment: "Member requesting a visit"
      add :date,           :utc_datetime,     null: false, comment: "Date of requested visit"
      add :minutes,        :integer,          null: false, comment: "Duration of the requested visit"
      add :tasks,          {:array, :string}, null: false, default: [], comment: "Tasks to be performed"
      add :pal_id,         references(:user,  on_delete: :delete_all), comment: "A pal who fulfills the visit"

      timestamps()
    end

    create index(:visit, [:member_id])
    create index(:visit, [:pal_id])
  end
end
