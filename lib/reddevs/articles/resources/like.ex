defmodule Reddevs.Articles.Like do
  use Ash.Resource,
    otp_app: :reddevs,
    domain: Reddevs.Articles,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "article_likes"
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
    belongs_to :post, Reddevs.Articles.Article do
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
    identity :unique_like, [:article_id, :user_id]
  end
end
