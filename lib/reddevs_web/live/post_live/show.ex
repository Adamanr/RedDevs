defmodule ReddevsWeb.PostLive.Show do
  use ReddevsWeb, :live_view

  import ReddevsWeb.CoreComponents
  alias ReddevsWeb.Helpers

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    current_user = socket.assigns.current_user

    post =
      Reddevs.Posts.Post
      |> Ash.Query.for_read(:by_slug, %{slug: slug}, actor: current_user)
      |> Ash.Query.load(:likes)
      |> Ash.read_one!(domain: Reddevs.Posts)

    if post do
      updated_post =
        post
        |> Ash.Changeset.for_update(:increment_views, %{user_id: current_user && current_user.id},
          actor: current_user
        )
        |> Ash.update!(domain: Reddevs.Posts, load: [:likes])

      user = Ash.get!(Reddevs.Accounts.User, post.author_id, domain: Reddevs.Accounts)

      has_liked =
        if current_user do
          Enum.any?(updated_post.likes, &(&1.user_id == current_user.id))
        else
          false
        end

      {:ok,
       socket
       |> assign(:post, updated_post)
       |> assign(:user, user)
       |> assign(:has_liked, has_liked)}
    else
      {:ok, redirect(socket, to: ~p"/posts")}
    end
  end

  @impl true
  def handle_event("like", _, socket) do
    current_user = socket.assigns.current_user

    if current_user do
      post = socket.assigns.post

      updated_post =
        if socket.assigns.has_liked do
          post
          |> Ash.Changeset.for_update(:unlike, %{user_id: current_user.id}, actor: current_user)
          |> Ash.update!(domain: Reddevs.Posts, load: [:likes])
        else
          post
          |> Ash.Changeset.for_update(:like, %{user_id: current_user.id}, actor: current_user)
          |> Ash.update!(domain: Reddevs.Posts, load: [:likes])
        end

      has_liked =
        if current_user do
          Enum.any?(updated_post.likes, &(&1.user_id == current_user.id))
        else
          false
        end

      {:noreply,
       socket
       |> assign(:post, updated_post)
       |> assign(:has_liked, has_liked)}
    else
      {:noreply,
       socket
       |> put_flash(:error, "Please sign in to like this post.")
       |> redirect(to: ~p"/sign-in")}
    end
  end
end
