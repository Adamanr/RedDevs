defmodule ReddevsWeb.UserLive.Profile do
  use ReddevsWeb, :live_view

  require Timex
  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"username" => username}, _session, socket) do
    current_user = socket.assigns[:current_user]

    user =
      Reddevs.Accounts.User
      |> Ash.Query.for_read(:get_by_username, %{username: username})
      |> Ash.read_one!()

    posts_query = Ash.Query.for_read(Reddevs.Posts.Post, :get_by_author, %{author_id: user.id})

    posts_query =
      if current_user && current_user.username == username do
        posts_query
      else
        Ash.Query.filter(posts_query, status == :published)
      end

    posts = Ash.read!(posts_query)

    {:noreply,
     socket
     |> assign(user_posts: posts)
     |> assign(user: user)
     |> assign(:is_current_user, current_user && current_user.username == username)}
  end

  defp get_pronounse(pronounse) do
    case pronounse do
      "she/her" -> "♀️ she/her"
      "he/him" -> "♂️ he/him"
      "robot" -> "🤖 robot"
      _ -> "who are you?.."
    end
  end

  defp format_datetime(datetime) do
    Timex.format!(datetime, "{Mshort} {D}, {YYYY} at {h24}:{m}")
  end
end
