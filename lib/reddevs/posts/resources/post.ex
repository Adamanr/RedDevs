defmodule Reddevs.Posts.Post do
  use Ash.Resource,
    otp_app: :reddevs,
    domain: Reddevs.Posts,
    data_layer: AshPostgres.DataLayer

  require Ash.Query

  postgres do
    table "posts"
    repo Reddevs.Repo
  end

  actions do
    defaults [:read, :destroy]

    read :by_slug do
      get_by [:slug]
    end

    read :get_by_author do
      description "Looks up posts by their author id"
      argument :author_id, :string, allow_nil?: false
      filter expr(author_id == ^arg(:author_id))
    end

    read :by_user do
      argument :user_id, :string, allow_nil?: false
      filter expr(author_id == ^arg(:user_id))
    end

    update :update do
      accept [
        :title,
        :content,
        :slug,
        :author_id,
        :tags,
        :header,
        :description,
        :status,
        :published_at
      ]
    end

    create :create do
      accept [:title, :content, :slug, :author_id, :tags, :header, :description, :status]
    end

    update :status do
      accept [:status]
    end

    update :publish do
      accept [:published_at]
      change set_attribute(:status, :published)
      change set_attribute(:published_at, &DateTime.utc_now/0)
    end

    update :increment_views do
      accept []
      argument :user_id, :uuid, allow_nil?: true
      require_atomic? false

      change fn changeset, _context ->
        user_id = Ash.Changeset.get_argument(changeset, :user_id)
        post_id = Ash.Changeset.get_attribute(changeset, :id)

        if user_id do
          view_query =
            Reddevs.Posts.View
            |> Ash.Query.filter(post_id == ^post_id and user_id == ^user_id)

          view_exists = Ash.exists?(view_query, domain: Reddevs.Posts)

          unless view_exists do
            Reddevs.Posts.View
            |> Ash.Changeset.for_create(:create, %{user_id: user_id, post_id: post_id})
            |> Ash.create!(domain: Reddevs.Posts)

            Ash.Changeset.atomic_update(changeset, :views_count, expr(views_count + 1))
          else
            changeset
          end
        else
          Ash.Changeset.atomic_update(changeset, :views_count, expr(views_count + 1))
        end
      end
    end

    update :like do
      accept []
      argument :user_id, :uuid, allow_nil?: false
      require_atomic? false

      change fn changeset, _context ->
        user_id = Ash.Changeset.get_argument(changeset, :user_id)
        post_id = Ash.Changeset.get_attribute(changeset, :id)

        like_query =
          Reddevs.Posts.Like
          |> Ash.Query.filter(post_id == ^post_id and user_id == ^user_id)

        like_exists = Ash.exists?(like_query, domain: Reddevs.Posts)

        unless like_exists do
          Reddevs.Posts.Like
          |> Ash.Changeset.for_create(:create, %{user_id: user_id, post_id: post_id})
          |> Ash.create!(domain: Reddevs.Posts)

          Ash.Changeset.atomic_update(changeset, :likes_count, expr(likes_count + 1))
        else
          changeset
        end
      end
    end

    update :unlike do
      accept []
      argument :user_id, :uuid, allow_nil?: false
      require_atomic? false

      change fn changeset, _context ->
        user_id = Ash.Changeset.get_argument(changeset, :user_id)
        post_id = Ash.Changeset.get_attribute(changeset, :id)

        like_query =
          Reddevs.Posts.Like
          |> Ash.Query.filter(post_id == ^post_id and user_id == ^user_id)

        like_exists = Ash.exists?(like_query, domain: Reddevs.Posts)

        if like_exists do
          Reddevs.Posts.Like
          |> Ash.Query.for_read(:read)
          |> Ash.Query.filter(post_id == ^post_id and user_id == ^user_id)
          |> Ash.bulk_destroy!(
            :destroy,
            %{},
            domain: Reddevs.Posts,
            strategy: :stream,
            return_errors?: true,
            authorize?: true
          )

          Ash.Changeset.atomic_update(changeset, :likes_count, expr(likes_count - 1))
        else
          changeset
        end
      end
    end

    update :increment_comment_count do
      accept []
      change atomic_update(:comments_count, expr(comments_count + 1))
    end

    update :decrement_comment_count do
      accept []
      argument :count, :integer, default: 1, allow_nil?: false
      require_atomic? false

      change fn changeset, _ ->
        count = Ash.Changeset.get_argument(changeset, :count)
        Ash.Changeset.atomic_update(changeset, :comments_count, expr(comments_count - ^count))
      end
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      allow_nil? false
      constraints max_length: 150
    end

    attribute :content, :string do
      allow_nil? false
    end

    attribute :slug, :string do
      allow_nil? false
    end

    attribute :status, :atom do
      constraints one_of: [:draft, :published, :rejected, :archived]
      default :draft
      allow_nil? true
    end

    attribute :description, :string do
      allow_nil? true
      constraints max_length: 300
      default ""
    end

    attribute :header, :string do
      allow_nil? true
    end

    attribute :tags, {:array, :string} do
      default []
    end

    attribute :views_count, :integer do
      default 0
      allow_nil? true
      public? true
    end

    attribute :likes_count, :integer do
      default 0
      allow_nil? true
      public? true
    end

    attribute :comments_count, :integer do
      default 0
      constraints min: 0
    end

    attribute :meta_description, :string do
      constraints max_length: 160
    end

    attribute :meta_keywords, {:array, :string} do
      default []
    end

    attribute :allow_comments, :boolean do
      default true
    end

    attribute :seo_optimized, :boolean do
      default false
    end

    attribute :published_at, :utc_datetime do
      allow_nil? true
    end

    timestamps()
  end

  relationships do
    belongs_to :author, Reddevs.Accounts.User do
      attribute_type :uuid
      attribute_writable? true
      allow_nil? false
      public? true
    end

    has_many :views, Reddevs.Posts.View do
      destination_attribute :post_id
      public? true
    end

    has_many :likes, Reddevs.Posts.Like do
      destination_attribute :post_id
      public? true
    end

    has_many :comments, Reddevs.Posts.Comment do
      destination_attribute :post_id
      public? true
    end
  end

  calculations do
    calculate :has_tags, :boolean, expr(^arg(:tag) in tags) do
      argument :tag, :string, allow_nil?: false
    end
  end

  identities do
    identity :unique_slug, [:slug]
  end
end
