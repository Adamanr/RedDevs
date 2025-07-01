defmodule Reddevs.Posts.View do
  use Ash.Resource,
    otp_app: :reddevs,
    domain: Reddevs.Posts,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "post_views"
    repo Reddevs.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:user_id, :post_id]
      primary? true
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :post_id, :uuid do
      allow_nil? false
    end

    attribute :user_id, :uuid do
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    belongs_to :post, Reddevs.Posts.Post do
      destination_attribute :id
      source_attribute :post_id
      allow_nil? false
      public? true
    end

    belongs_to :user, Reddevs.Accounts.User do
      destination_attribute :id
      source_attribute :user_id
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :unique_view, [:post_id, :user_id]
  end
end
