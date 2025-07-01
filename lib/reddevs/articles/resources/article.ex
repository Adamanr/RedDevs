defmodule Reddevs.Articles.Article do
  use Ash.Resource,
    domain: Reddevs.Articles,
    data_layer: AshPostgres.DataLayer

  require Ash.Query

  postgres do
    table "articles"
    repo Reddevs.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      accept [
        :title,
        :content,
        :excerpt,
        :featured_image_url,
        :tags,
        :slug,
        :author_id,
        :category,
        :allow_comments
      ]
    end

    update :update do
      accept [
        :title,
        :content,
        :excerpt,
        :featured_image_url,
        :meta_description,
        :meta_keywords,
        :tags,
        :category,
        :allow_comments
      ]
    end

    update :publish do
      accept []
      change set_attribute(:status, :published)
      change set_attribute(:published_at, &DateTime.utc_now/0)
    end

    update :unpublish do
      accept []
      change set_attribute(:status, :draft)
      change set_attribute(:published_at, nil)
    end

    update :archive do
      accept []
      change set_attribute(:status, :archived)
    end

    update :feature do
      accept []
      change set_attribute(:is_featured, true)
    end

    update :unfeature do
      accept []
      change set_attribute(:is_featured, false)
    end

    read :published do
      filter expr(status == :published)
      prepare build(sort: [published_at: :desc])
    end

    read :by_slug do
      argument :slug, :string, allow_nil?: false
      get? true
      filter expr(slug == ^arg(:slug))
    end

    read :by_author do
      argument :author_id, :uuid, allow_nil?: false
      filter expr(author_id == ^arg(:author_id))
      prepare build(sort: [inserted_at: :desc])
    end

    read :by_category do
      argument :category, :uuid, allow_nil?: false
      filter expr(category == ^arg(:category))
      prepare build(sort: [published_at: :desc])
    end

    read :by_tag do
      argument :tag, :string, allow_nil?: false
      filter expr(^arg(:tag) in tags)
      prepare build(sort: [published_at: :desc])
    end

    read :featured do
      filter expr(is_featured == true and status == :published)
      prepare build(sort: [published_at: :desc])
    end

    read :popular do
      filter expr(status == :published)
      prepare build(sort: [view_count: :desc, like_count: :desc])
    end

    read :recent do
      filter expr(status == :published)
      prepare build(sort: [published_at: :desc])
    end

    update :increment_views do
      accept []
      argument :user_id, :uuid, allow_nil?: true
      require_atomic? false

      change fn changeset, _context ->
        user_id = Ash.Changeset.get_argument(changeset, :user_id)
        article_id = Ash.Changeset.get_attribute(changeset, :id)

        if user_id do
          view_query =
            Reddevs.Articles.View
            |> Ash.Query.filter(article_id == ^article_id and user_id == ^user_id)

          view_exists = Ash.exists?(view_query, domain: Reddevs.Articles)

          unless view_exists do
            Reddevs.Articles.View
            |> Ash.Changeset.for_create(:create, %{user_id: user_id, article_id: article_id})
            |> Ash.create!(domain: Reddevs.Articles)

            Ash.Changeset.atomic_update(changeset, :view_count, expr(view_count + 1))
          else
            changeset
          end
        else
          Ash.Changeset.atomic_update(changeset, :view_count, expr(view_count + 1))
        end
      end
    end

    update :like do
      accept []
      argument :user_id, :uuid, allow_nil?: false
      require_atomic? false

      change fn changeset, _context ->
        user_id = Ash.Changeset.get_argument(changeset, :user_id)
        article_id = Ash.Changeset.get_attribute(changeset, :id)

        like_query =
          Reddevs.Articles.Like
          |> Ash.Query.filter(article_id == ^article_id and user_id == ^user_id)

        like_exists = Ash.exists?(like_query, domain: Reddevs.Articles)

        unless like_exists do
          Reddevs.Articles.Like
          |> Ash.Changeset.for_create(:create, %{user_id: user_id, article_id: article_id})
          |> Ash.create!(domain: Reddevs.Articles)

          Ash.Changeset.atomic_update(changeset, :like_count, expr(like_count + 1))
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
        article_id = Ash.Changeset.get_attribute(changeset, :id)

        like_query =
          Reddevs.Articles.Like
          |> Ash.Query.filter(article_id == ^article_id and user_id == ^user_id)

        like_exists = Ash.exists?(like_query, domain: Reddevs.Articles)

        if like_exists do
          Reddevs.Articles.Like
          |> Ash.Query.for_read(:read)
          |> Ash.Query.filter(article_id == ^article_id and user_id == ^user_id)
          |> Ash.bulk_destroy!(
            :destroy,
            %{},
            domain: Reddevs.Articles,
            strategy: :stream,
            return_errors?: true,
            authorize?: true
          )

          Ash.Changeset.atomic_update(changeset, :like_count, expr(like_count - 1))
        else
          changeset
        end
      end
    end

    update :add_comment do
      argument :comment, :map do
        allow_nil? false
      end

      require_atomic? false

      change manage_relationship(:comment, :comments, type: :append)

      change fn changeset, _ ->
        # Используем Ash.Changeset для атомарного обновления
        Ash.Changeset.atomic_update(changeset, :comment_count, expr(comment_count + 1))
      end
    end

    update :increment_comment_count do
      accept []
      require_atomic? false

      change fn changeset, _ ->
        Ash.Changeset.atomic_update(changeset, :comment_count, expr(comment_count + 1))
      end
    end

    update :decrement_comment_count do
      accept []
      argument :count, :integer, default: 1, allow_nil?: false
      require_atomic? false

      change fn changeset, _ ->
        count = Ash.Changeset.get_argument(changeset, :count)
        Ash.Changeset.atomic_update(changeset, :comment_count, expr(comment_count - ^count))
      end
    end
  end

  preparations do
    prepare build(load: [:author])
  end

  attributes do
    uuid_primary_key :id

    attribute :title, :string do
      allow_nil? false
      constraints min_length: 1, max_length: 255
    end

    attribute :slug, :string do
      allow_nil? false
      constraints min_length: 1, max_length: 255
    end

    attribute :excerpt, :string do
      constraints max_length: 500
    end

    attribute :category, :string do
      allow_nil? false
    end

    attribute :content, :string do
      allow_nil? false
      constraints min_length: 1
    end

    attribute :content_html, :string do
      description "Rendered HTML content from markdown"
    end

    attribute :featured_image_url, :string do
      constraints max_length: 500
    end

    attribute :meta_description, :string do
      constraints max_length: 160
    end

    attribute :meta_keywords, {:array, :string} do
      default []
    end

    attribute :tags, {:array, :string} do
      default []
    end

    attribute :status, :atom do
      constraints one_of: [:draft, :published, :archived]
      default :draft
    end

    attribute :published_at, :utc_datetime_usec

    attribute :reading_time_minutes, :integer do
      default 0
      description "Estimated reading time in minutes"
    end

    attribute :view_count, :integer do
      default 0
      constraints min: 0
    end

    attribute :like_count, :integer do
      default 0
      constraints min: 0
    end

    attribute :comment_count, :integer do
      default 0
      constraints min: 0
    end

    attribute :is_featured, :boolean do
      default false
    end

    attribute :allow_comments, :boolean do
      default true
    end

    attribute :seo_optimized, :boolean do
      default false
    end

    create_timestamp :inserted_at
    update_timestamp :updated_at
  end

  relationships do
    belongs_to :author, Reddevs.Accounts.User do
      attribute_type :uuid
      attribute_writable? true
      allow_nil? false
      public? true
    end

    has_many :views, Reddevs.Articles.View do
      destination_attribute :article_id
      public? true
    end

    has_many :likes, Reddevs.Articles.Like do
      destination_attribute :article_id
      public? true
    end

    has_many :comments, Reddevs.Articles.Comment do
      destination_attribute :article_id
      public? true
    end
  end

  identities do
    identity :unique_slug, [:slug]
  end
end
