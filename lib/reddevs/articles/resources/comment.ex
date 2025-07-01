defmodule Reddevs.Articles.Comment do
  use Ash.Resource,
    domain: Reddevs.Articles,
    data_layer: AshPostgres.DataLayer

  require Ash.Query

  postgres do
    table "article_comments"
    repo Reddevs.Repo
  end

  actions do
    defaults [:read, :destroy, :update]

    read :by_article do
      argument :article_id, :uuid, allow_nil?: false
      filter expr(article_id == ^arg(:article_id))
      prepare build(sort: [inserted_at: :desc])
    end

    create :create do
      accept [:content, :author_id, :article_id, :parent_id]
    end

    read :with_replies do
      argument :include_replies, :boolean, allow_nil?: false, default: true

      prepare fn query, _ ->
        if Ash.Query.get_argument(query, :include_replies) do
          Ash.Query.load(query, :replies)
        else
          query
        end
      end
    end

    create :reply do
      accept [:content, :parent_id, :author_id, :article_id]
      require_attributes [:article_id]

      change fn changeset, _ ->
        parent_id = Ash.Changeset.get_attribute(changeset, :parent_id)

        if parent_id do
          case __MODULE__
               |> Ash.Query.filter(id == ^parent_id)
               |> Ash.read_one() do
            {:ok, %{article_id: article_id}} ->
              Ash.Changeset.force_change_attribute(changeset, :article_id, article_id)

            {:error, _} ->
              Ash.Changeset.add_error(changeset,
                field: :parent_id,
                message: "Parent comment not found"
              )
          end
        else
          changeset
        end
      end
    end

    update :update_content do
      accept [:content]
    end

    update :hide_comment do
      accept []
      change set_attribute(:is_hidden, true)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :content, :string do
      allow_nil? false
      constraints min_length: 1, max_length: 2000, trim?: true
    end

    attribute :parent_id, :uuid do
      allow_nil? true
    end

    attribute :is_hidden, :boolean do
      default false
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :article, Reddevs.Articles.Article do
      attribute_type :uuid
      allow_nil? false
      public? true
    end

    belongs_to :author, Reddevs.Accounts.User do
      attribute_type :uuid
      allow_nil? false
      public? true
    end

    belongs_to :parent, __MODULE__ do
      attribute_type :uuid
      attribute_writable? true
      source_attribute :parent_id
      allow_nil? true
      public? true
    end

    has_many :replies, __MODULE__ do
      destination_attribute :parent_id
      public? true
    end
  end
end
