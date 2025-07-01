defmodule ReddevsWeb.ArticleLive.Index do
  use ReddevsWeb, :live_view

  require Ash.Query
  alias ReddevsWeb.Helpers

  @impl true
  def mount(_params, _session, socket) do
    categories = ["AI", "Blockchain", "Web3", "Elixir", "Phoenix", "Frontend", "DevOps"]

    articles =
      Reddevs.Articles.Article
      |> Ash.Query.load([:author])
      |> Ash.Query.filter(status == :published)
      |> Ash.read!()

    {:ok,
     socket
     |> assign(:page_title, "Статьи")
     |> assign(:filters, %{status: :published})
     |> assign(:categories, categories)
     |> stream(:articles, articles)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    filters =
      %{
        status: :published,
        title: params["title"],
        category: params["category"]
      }
      |> Enum.filter(fn {_, v} -> not is_nil(v) and v != "" end)
      |> Map.new()

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> stream(:articles, load_articles(filters), reset: true)}
  end

  @impl true
  def handle_event("filter", %{"title" => title, "category" => category}, socket) do
    merged_filters =
      socket.assigns.filters
      |> Map.put(:title, if(title == "", do: nil, else: title))
      |> Map.put(:category, if(category == "", do: nil, else: category))

    {:noreply,
     socket
     |> assign(:filters, merged_filters)
     |> stream(:articles, load_articles(merged_filters), reset: true)}
  end

  defp load_articles(filters) do
    base_query =
      Reddevs.Articles.Article
      |> Ash.Query.load([:author])
      |> Ash.Query.filter(status == :published)

    query =
      base_query
      |> filter_by_title(filters)
      |> filter_by_category(filters)

    Ash.read!(query)
  end

  defp filter_by_title(query, %{title: title}) when is_binary(title) and title != "" do
    search_term = "%#{String.replace(title, "%", "\\%")}%"
    Ash.Query.filter(query, ilike(title, ^search_term))
  end

  defp filter_by_title(query, _), do: query

  defp filter_by_category(query, %{category: category})
       when is_binary(category) and category != "" do
    Ash.Query.filter(query, category == ^category)
  end

  defp filter_by_category(query, _), do: query
end
