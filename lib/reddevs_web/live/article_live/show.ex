defmodule ReddevsWeb.ArticleLive.Show do
  use ReddevsWeb, :live_view

  alias Reddevs.Articles
  alias ReddevsWeb.Helpers

  require Ash.Query
  use Timex

  @impl true
  def mount(%{"slug" => slug}, _uri, socket) do
    current_user = socket.assigns.current_user

    article =
      Articles.Article
      |> Ash.Query.for_read(:by_slug, %{slug: slug}, actor: current_user)
      |> Ash.Query.load([:author, :likes, :views])
      |> Ash.read_one!(domain: Reddevs.Posts)

    similar_articles = get_similar_articles(article)

    if article do
      update_article =
        article
        |> Ash.Changeset.for_update(:increment_views, %{user_id: current_user && current_user.id},
          actor: current_user
        )
        |> Ash.update!(domain: Reddevs.Articles, load: [:likes])

      user = Ash.get!(Reddevs.Accounts.User, article.author_id, domain: Reddevs.Accounts)

      has_liked =
        if current_user do
          Enum.any?(update_article.likes, &(&1.user_id == current_user.id))
        else
          false
        end

      {:ok,
       socket
       |> assign(:page_title, "#{article.title}")
       |> assign(:article, update_article)
       |> assign(:comments, article.comments || [])
       |> assign(:similar_articles, similar_articles)
       |> assign(:user, user)
       |> assign(:has_liked, has_liked)}
    else
      {:ok, redirect(socket, to: ~p"/articles")}
    end
  end

  @impl true
  def handle_event("like", _, socket) do
    current_user = socket.assigns.current_user

    if current_user do
      article = socket.assigns.article

      update_article =
        if socket.assigns.has_liked do
          article
          |> Ash.Changeset.for_update(:unlike, %{user_id: current_user.id}, actor: current_user)
          |> Ash.update!(domain: Reddevs.Articles, load: [:likes])
        else
          article
          |> Ash.Changeset.for_update(:like, %{user_id: current_user.id}, actor: current_user)
          |> Ash.update!(domain: Reddevs.Articles, load: [:likes])
        end

      has_liked =
        if current_user do
          Enum.any?(update_article.likes, &(&1.user_id == current_user.id))
        else
          false
        end

      {:noreply,
       socket
       |> assign(:article, update_article)
       |> assign(:has_liked, has_liked)}
    else
      {:noreply,
       socket
       |> put_flash(:error, "Please sign in to like this post.")
       |> redirect(to: ~p"/sign-in")}
    end
  end

  defp get_similar_articles(_article) do
    Reddevs.Articles.Article
    |> Ash.Query.for_read(:published)
    # |> Ash.Query.filter(id == article.id)
    # |> Ash.Query.filter(expr(fragment("? @> ?", tags, article.tags)))
    # |> Ash.Query.filter(category == article.category or article.tags in tags)
    |> Ash.Query.limit(2)
    |> Ash.read!()
  end
end
