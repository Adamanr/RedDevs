defmodule ReddevsWeb.PostLive.Form do
  use ReddevsWeb, :live_view

  @impl true
  def mount(params, _session, socket) do
    post =
      case params["slug"] do
        nil ->
          nil

        slug ->
          Reddevs.Posts.Post
          |> Ash.Query.for_read(:by_slug, %{slug: slug}, actor: socket.assigns.current_user)
          |> Ash.read_one!()
      end

    action = if is_nil(post), do: "New", else: "Edit"
    page_title = action <> " " <> "Post"
    all_tags = get_all_tags()
    selected_tags = if post, do: post.tags || [], else: []

    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> assign(post: post)
     |> assign(:page_title, page_title)
     |> assign(:all_tags, all_tags)
     |> assign(:selected_tags, selected_tags)
     |> assign_form()}
  end

  defp get_all_tags do
    Ash.read!(Reddevs.Posts.Post) |> Enum.flat_map(& &1.tags) |> Enum.uniq()
  end

  @impl true
  def handle_info({ReddevsWeb.Components.Live.Tags, :tags_updated, selected_tags}, socket) do
    {:noreply, assign(socket, :selected_tags, selected_tags)}
  end

  @impl true
  def handle_info({:hide_suggestions, _id}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("validate", %{"post" => post_params}, socket) do
    post_params = Map.put(post_params, "tags", socket.assigns.selected_tags)
    {:noreply, assign(socket, form: AshPhoenix.Form.validate(socket.assigns.form, post_params))}
  end

  @impl true
  def handle_event("save_draft", _, socket) do
    save_post(socket, "draft")
  end

  @impl true
  def handle_event("save_publish", _, socket) do
    save_post(socket, "published")
  end

  defp save_post(socket, status) do
    post_params =
      socket.assigns.form.params
      |> Map.put("tags", socket.assigns.selected_tags)
      |> Map.put("status", status)
      |> Map.put("author_id", socket.assigns.current_user.id)

    case AshPhoenix.Form.submit(socket.assigns.form, params: post_params) do
      {:ok, post} ->
        if status == "published" do
          case Ash.update(post,
                 action: :publish,
                 actor: socket.assigns.current_user
               ) do
            {:ok, updated_post} ->
              handle_success(socket, updated_post, status)

            {:error, error} ->
              IO.inspect(error, label: "Error updating published_at")
              {:noreply, put_flash(socket, :error, "Failed to set publication date")}
          end
        else
          handle_success(socket, post, status)
        end

      {:error, form} ->
        IO.inspect(form, label: "Error form")
        {:noreply, assign(socket, form: form)}
    end
  end

  defp handle_success(socket, post, status) do
    notify_parent({:saved, post})

    socket =
      socket
      |> put_flash(:info, "Post saved as #{status} successfully")
      |> push_navigate(to: "/posts/#{post.slug}")

    {:noreply, socket}
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp assign_form(%{assigns: %{post: post}} = socket) do
    form =
      if post do
        AshPhoenix.Form.for_update(post, :update, as: "post", actor: socket.assigns.current_user)
      else
        AshPhoenix.Form.for_create(Reddevs.Posts.Post, :create,
          as: "post",
          actor: socket.assigns.current_user
        )
      end

    assign(socket, form: to_form(form))
  end

  defp return_to(_), do: "index"

  defp return_path("index", _post), do: ~p"/posts"
  defp return_path("show", %{slug: slug}), do: ~p"/posts/#{slug}"
  defp return_path("show", post) when is_map(post), do: ~p"/posts/#{post.slug}"
  defp return_path(_, _), do: ~p"/posts"
end
