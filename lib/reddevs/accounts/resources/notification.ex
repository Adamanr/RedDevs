defmodule Reddevs.Accounts.Notification do
  use Ash.Resource,
    otp_app: :reddevs,
    domain: Reddevs.Accounts,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "notifications"
    repo Reddevs.Repo
  end

  attributes do
    uuid_primary_key :id
    attribute :type, :string
    attribute :read, :boolean, default: false
    attribute :metadata, :map
    attribute :inserted_at, :utc_datetime_usec, default: &DateTime.utc_now/0
  end

  relationships do
    belongs_to :user, Reddevs.Accounts.User, allow_nil?: false
  end
end
