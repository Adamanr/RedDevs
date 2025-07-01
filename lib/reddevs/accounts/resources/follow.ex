defmodule Reddevs.Accounts.Follow do
  use Ash.Resource,
    otp_app: :reddevs,
    domain: Reddevs.Accounts,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "follows"
    repo Reddevs.Repo
  end

  actions do
    create :create do
      accept [:follower_id, :followed_id]
    end
  end

  attributes do
    uuid_primary_key :id
    attribute :follower_id, :uuid, allow_nil?: false
    attribute :followed_id, :uuid, allow_nil?: false
    create_timestamp :inserted_at
  end

  relationships do
    belongs_to :follower, Reddevs.Accounts.User do
      primary_key? true
      allow_nil? false
    end

    belongs_to :followed, Reddevs.Accounts.User do
      primary_key? true
      allow_nil? false
    end
  end
end
