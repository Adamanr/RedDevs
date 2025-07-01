defmodule ReddevsWeb.ArticleLive.Form do
  use ReddevsWeb, :live_view
  alias Reddevs.Articles
  alias Reddevs.Articles.Article

  @impl true
  def mount(params, _session, socket) do
    current_user = socket.assigns.current_user
    categories = ["Elixir", "Phoenix", "AI", "Blockchain", "Frontend", "DevOps", "Web3"]

    {article, action} =
      case params["slug"] do
        nil ->
          # Создаем пустую структуру для новой статьи
          {%Article{}, :new}

        slug ->
          article =
            Articles.Article
            |> Ash.Query.for_read(:by_slug, %{slug: slug})
            |> Ash.read_one!()

          {article, :edit}
      end

    all_tags = get_all_tags()
    selected_tags = article.tags || []

    form_source =
      if action == :edit do
        AshPhoenix.Form.for_update(article, :update,
          actor: current_user,
          forms: [auto?: true]
        )
      else
        AshPhoenix.Form.for_create(Article, :create,
          actor: current_user,
          forms: [auto?: true]
        )
      end

    form = to_form(form_source, as: "form")

    page_title =
      case action do
        :edit -> "Редактирование статьи"
        :new -> "Создание статьи"
      end

    {:ok,
     socket
     |> assign(:current_user, current_user)
     |> assign(:article, article)
     |> assign(:action, action)
     |> assign(:categories, categories)
     |> assign(:all_tags, all_tags)
     |> assign(:selected_tags, selected_tags)
     |> assign(:tag_search, "")
     |> assign(:suggested_tags, [])
     |> assign(:show_suggestions, false)
     |> assign(:form, form)
     |> assign(:page_title, page_title)}
  end

  defp get_all_tags do
    try do
      Articles.Article
      |> Ash.Query.for_read(:read)
      |> Ash.read!()
      |> Enum.flat_map(& &1.tags)
      |> Enum.uniq()
      |> Enum.reject(&is_nil/1)
    rescue
      _ -> []
    end
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
  def handle_event("validate", params, socket) do
    article_params =
      case params do
        %{"form" => form_params} -> form_params
        %{"article" => article_params} -> article_params
        _ -> %{}
      end

    article_params =
      article_params
      |> Map.put("tags", socket.assigns.selected_tags)
      |> Map.put("author_id", socket.assigns.current_user.id)

    article_params =
      if socket.assigns.action == :new and not Map.has_key?(article_params, "slug") do
        slug = generate_slug(article_params["title"] || "")
        Map.put(article_params, "slug", slug)
      else
        article_params
      end

    form = AshPhoenix.Form.validate(socket.assigns.form.source, article_params)
    {:noreply, assign(socket, :form, to_form(form, as: "form"))}
  end

  @impl true
  def handle_event("save", params, socket) do
    button_type =
      case params do
        %{"button" => type} -> type
        %{"_target" => ["button"]} -> Map.get(params, "button", "draft")
        _ -> "draft"
      end

    article_params =
      socket.assigns.form.params
      |> Map.put("author_id", socket.assigns.current_user.id)
      |> Map.put("tags", socket.assigns.selected_tags)

    article_params =
      if socket.assigns.action == :new do
        slug = generate_slug(article_params["title"] || "")
        Map.put(article_params, "slug", slug)
      else
        article_params
      end

    case AshPhoenix.Form.submit(socket.assigns.form.source, params: article_params) do
      {:ok, article} ->
        type =
          case button_type do
            "publish" -> :publish
            "draft" -> :unpublish
            "archive" -> :archive
            _ -> :update
          end

        changeset =
          article
          |> Ash.Changeset.for_update(type, %{}, actor: socket.assigns.current_user)

        case Ash.update(changeset) do
          {:ok, published_article} ->
            handle_success(socket, published_article, ~s(Статья успешно опубликована!))

          {:error, error} ->
            handle_success(
              socket,
              article,
              ~s(Статья сохранена, но не удалось опубликовать: #{inspect(error)})
            )
        end

      # handle_success(socket, article, ~s(Статья успешно сохранена!))

      {:error, form} ->
        {:noreply,
         socket
         |> assign(:form, to_form(form, as: "form"))
         |> put_flash(:error, ~s(Проверьте правильность заполнения полей))}
    end
  end

  @impl true
  def handle_event("archive", _params, socket) do
    changeset =
      Ash.Changeset.for_update(socket.assigns.article, :archive, %{},
        actor: socket.assigns.current_user
      )

    case Ash.update(changeset) do
      {:ok, _article} ->
        {:noreply,
         socket
         |> put_flash(:info, ~s(Статья перемещена в архив))
         |> push_navigate(to: ~p"/articles/#{socket.assigns.article.slug}")}

      {:error, error} ->
        {:noreply,
         socket
         |> put_flash(:error, ~s(Ошибка при архивации: #{inspect(error)}))}
    end
  end

  @impl true
  def handle_event("delete", _params, socket) do
    case Ash.destroy(socket.assigns.article, actor: socket.assigns.current_user) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, ~s(Статья удалена))
         |> push_navigate(to: ~p"/articles")}

      {:error, error} ->
        {:noreply,
         socket
         |> put_flash(:error, ~s(Ошибка при удалении: #{inspect(error)}))}
    end
  end

  # Генерация slug из заголовка
  defp generate_slug(title) when is_binary(title) do
    title
    |> String.downcase()
    |> String.replace(~r/[^\w\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.trim("-")
    |> case do
      "" -> "article-#{System.unique_integer([:positive])}"
      slug -> slug
    end
  end

  defp generate_slug(_), do: "article-#{System.unique_integer([:positive])}"

  defp handle_success(socket, article, message) do
    {:noreply,
     socket
     |> put_flash(:info, message)
     |> push_navigate(to: ~p"/articles/#{article.slug}")}
  end
end
