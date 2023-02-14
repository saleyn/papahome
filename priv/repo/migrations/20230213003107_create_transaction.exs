defmodule Papahome.Repo.Migrations.CreateTransaction do
  use Ecto.Migration

  def change do
    create table(:transaction, comment: "Defines a visit fulfilment transaction between a pal and a member") do
      add :member_id,    references(:user,  on_delete: :delete_all), null: false
      add :pal_id,       references(:user,  on_delete: :delete_all)
      add :visit_id,     references(:visit, on_delete: :delete_all)
      add :description,  :string,               comment: "Description of this transaction"
      add :minutes,      :integer, null: false, comment: "Minutes value for this transaction"
      add :fee_minutes,  :integer, null: false, comment: "Fee minutes charged"
      add :fulfilled_at, :utc_datetime,         comment: "Timestamp when the visit was fulfilled"

      timestamps()
    end

    create unique_index(:transaction, [:member_id, :pal_id, :visit_id])
  end
end
