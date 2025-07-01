defmodule Reddevs.Articles.View do
  use Ash.Resource,
    otp_app: :reddevs,
    domain: Reddevs.Articles,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "article_views"
    repo Reddevs.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:user_id, :article_id]
      primary? true
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :article_id, :uuid do
      allow_nil? false
    end

    attribute :user_id, :uuid do
      allow_nil? false
    end

    timestamps()
  end

  relationships do
    belongs_to :article, Reddevs.Articles.Article do
      destination_attribute :id
      source_attribute :article_id
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
    identity :unique_view, [:article_id, :user_id]
  end
end
