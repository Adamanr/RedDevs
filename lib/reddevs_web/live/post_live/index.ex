defmodule ReddevsWeb.PostLive.Index do
  use ReddevsWeb, :live_view
  require Ash.Query

  @impl true
  def mount(_params, _session, socket) do
    popular_tags = get_popular_tags()

    {:ok,
     socket
     |> assign(:page_title, "Listing Posts")
     |> assign(:filters, %{status: :published})
     |> assign(:popular_tags, popular_tags)
     |> assign(:loading, false)
     |> assign(:show_filter, false)
     |> stream(:posts, load_posts(%{status: :published}))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    filters = parse_filters(params)

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> stream(:posts, load_posts(filters), reset: true)}
  end

  @impl true
  def handle_event("show_filter", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_filter, !socket.assigns.show_filter)
     |> stream(:posts, load_posts(socket.assigns.filters), reset: true)}
  end

  @impl true
  def handle_event("apply_filters", params, socket) do
    new_filters = parse_filters(params)
    merged_filters = Map.merge(socket.assigns.filters, new_filters)

    {:noreply,
     socket
     |> assign(:filters, merged_filters)
     |> push_patch(to: ~p"/posts?#{merged_filters}")}
  end

  @impl true
  def handle_event("reset_filters", _, socket) do
    filters = %{status: :published}

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> push_patch(to: ~p"/posts")}
  end

  @impl true
  def handle_info({ReddevsWeb.Components.Live.Tags, :tags_updated, selected_tags}, socket) do
    filters = Map.put(socket.assigns.filters, :tags, selected_tags)

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> push_patch(to: ~p"/posts?#{filters}")}
  end

  def handle_info({:hide_suggestions, _id}, socket) do
    {:noreply, socket}
  end

  defp parse_filters(params) do
    %{}
    |> maybe_add_filter(params, "status")
    |> maybe_add_filter(params, "title")
    |> maybe_add_filter(params, "from_date")
    |> maybe_add_filter(params, "to_date")
    |> maybe_add_list_filter(params, "tags")
    |> Map.put_new(:status, :published)
  end

  defp load_posts(filters) do
    base_query =
      Reddevs.Posts.Post
      |> Ash.Query.filter(status == :published)
      |> Ash.Query.load(:author)

    query =
      base_query
      |> filter_by_tags(filters)
      |> filter_by_title(filters)
      |> filter_by_date_range(filters)

    Ash.read!(query)
  end

  defp filter_by_title(query, %{title: title}) when is_binary(title) and title != "" do
    search_term = "%#{String.replace(title, "%", "\\%")}%"
    Ash.Query.filter(query, ilike(title, ^search_term))
  end

  defp filter_by_title(query, _), do: query

  defp parse_datetime(nil), do: nil
  defp parse_datetime(""), do: nil

  defp parse_datetime(datetime_string) do
    case DateTime.from_iso8601(datetime_string <> ":00Z") do
      {:ok, datetime, _} -> datetime
      _ -> nil
    end
  end

  defp filter_by_date_range(query, filters) do
    from_date = parse_datetime(Map.get(filters, :from_date))
    to_date = parse_datetime(Map.get(filters, :to_date))

    if from_date && to_date && DateTime.compare(from_date, to_date) == :gt do
      query
      |> maybe_filter_after(to_date)
      |> maybe_filter_before(from_date)
    else
      query
      |> maybe_filter_after(from_date)
      |> maybe_filter_before(to_date)
    end
  end

  defp maybe_filter_after(query, nil), do: query

  defp maybe_filter_after(query, datetime) do
    Ash.Query.filter(query, inserted_at >= ^datetime)
  end

  defp maybe_filter_before(query, nil), do: query

  defp maybe_filter_before(query, datetime) do
    Ash.Query.filter(query, inserted_at <= ^datetime)
  end

  defp filter_by_tags(query, %{tags: tags}) when is_list(tags) and tags != [] do
    normalized_tags = Enum.map(tags, &String.downcase/1)
    Ash.Query.filter(query, fragment("lower(tags::text)::text[] @> ?", ^normalized_tags))
  end

  defp filter_by_tags(query, _), do: query

  defp maybe_add_filter(filters, params, key) do
    if value = params[key], do: Map.put(filters, String.to_atom(key), value), else: filters
  end

  defp maybe_add_list_filter(filters, params, key) do
    if values = params[key] do
      tags =
        if is_binary(values), do: String.split(values, ","), else: values

      Map.put(filters, :tags, tags)
    else
      filters
    end
  end

  defp get_popular_tags do
    Reddevs.Posts.Post
    |> Ash.Query.filter(status == :published)
    |> Ash.read!()
    |> Enum.flat_map(& &1.tags)
    |> Enum.frequencies()
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.map(&elem(&1, 0))
    |> Enum.take(10)
  end

  def filter_option(assigns) do
    ~H"""
    <div class="filter-option mt-2">
      <input
        type="radio"
        name={@name}
        id={"filter-#{@name}-#{@value}"}
        value={@value}
        checked={@checked}
        class="hidden"
        phx-click="apply_filter"
        phx-value-name={@name}
        phx-value-value={@value}
      />
      <label
        for={"filter-#{@name}-#{@value}"}
        class="filter-option-label"
        style={"--glow-color: #{@color}"}
      >
        {@label}
      </label>
    </div>
    """
  end

  def tag_filter(assigns) do
    ~H"""
    <div class="tag-filter mt-2">
      <input
        type="checkbox"
        name="tags[]"
        id={"tag-#{@tag}"}
        value={@tag}
        class="hidden"
        checked={@selected}
        phx-click="toggle_tag"
        phx-value-tag={@tag}
      />
      <label for={"tag-#{@tag}"} class={"tag-filter-item #{if @selected, do: ~c'selected'}"}>
        {@tag}
      </label>
    </div>
    """
  end
end
