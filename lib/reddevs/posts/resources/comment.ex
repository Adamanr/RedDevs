defmodule Reddevs.Posts.Comment do
  use Ash.Resource,
    domain: Reddevs.Posts,
    data_layer: AshPostgres.DataLayer

  require Ash.Query

  postgres do
    table "post_comments"
    repo Reddevs.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [:content, :author_id, :post_id, :parent_id]
      require_attributes [:content, :author_id, :post_id]
    end

    create :reply do
      accept [:content, :parent_id, :author_id, :post_id]
      require_attributes [:content, :author_id, :post_id]

      change fn changeset, _ ->
        parent_id = Ash.Changeset.get_attribute(changeset, :parent_id)

        if parent_id do
          case __MODULE__
               |> Ash.Query.filter(id == ^parent_id)
               |> Ash.read_one() do
            {:ok, %{post_id: post_id}} ->
              Ash.Changeset.force_change_attribute(changeset, :post_id, post_id)

            {:ok, nil} ->
              Ash.Changeset.add_error(changeset,
                field: :parent_id,
                message: "Parent comment not found"
              )

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
      require_attributes [:content]
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
    belongs_to :post, Reddevs.Posts.Post do
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
