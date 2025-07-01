defmodule ReddevsWeb.Components.Live.Tags do
  use Phoenix.LiveComponent
  use ReddevsWeb, :html

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:tag_search, "")
     |> assign(:suggested_tags, [])
     |> assign(:show_suggestions, false)
     |> assign(:allow_new_tags, false)}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(:all_tags, assigns.all_tags)
      |> assign(:selected_tags, assigns.initial_selected_tags || [])
      |> assign(:id, assigns.id)
      |> assign(:allow_new_tags, assigns.allow_new_tags || false)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="tags-container w-full">
      <div class="selected-tags flex flex-wrap gap-2">
        <div
          :for={tag <- @selected_tags}
          class="tag-item inline-flex items-center px-3 py-1 bg-gray-800 border border-cyan-500/30 rounded-full text-cyan-200 text-sm font-bold"
        >
          <span class="tag-text mr-2">{tag}</span>
          <button
            type="button"
            phx-click="remove_tag"
            phx-value-tag={tag}
            phx-target={@myself}
            class="tag-remove text-cyan-400 hover:text-cyan-200"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 24 24"
              fill="currentColor"
              class="w-4 h-4"
            >
              <path d="M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z" />
            </svg>
          </button>
          <div class="tag-glow"></div>
        </div>
      </div>

      <div class="tag-input-container relative mt-2">
        <input
          type="text"
          value={@tag_search}
          phx-keyup="search_tags"
          phx-keydown="select_first_tag"
          phx-focus="show_tag_suggestions"
          phx-blur="hide_tag_suggestions"
          phx-target={@myself}
          placeholder={
            if @allow_new_tags, do: "Type a tag and press enter...", else: "Search existing tags..."
          }
          class="tag-input w-full bg-gray-800 border border-cyan-500/30 rounded-lg py-3 px-4 text-cyan-200 focus:outline-none focus:ring-2 focus:ring-cyan-500"
        />
        <div class="terminal-cursor absolute right-4 top-3.5 h-6 w-2 bg-cyan-400 animate-blink"></div>
      </div>

      <div
        :if={@show_suggestions and @tag_search != ""}
        class="tag-suggestions absolute z-10 mt-1 w-full bg-gray-900 border border-cyan-500/30 rounded-lg shadow-lg"
      >
        <div class="suggestion-header px-4 py-2 text-cyan-300 font-mono text-sm border-b border-cyan-500/30">
          Suggestions
        </div>
        <%= if @suggested_tags == [] do %>
          <div class="px-4 py-2 text-cyan-200 text-sm">No matching tags found.</div>
        <% else %>
          <button
            :for={tag <- @suggested_tags}
            type="button"
            phx-click="add_existing_tag"
            phx-value-tag={tag}
            phx-target={@myself}
            class="suggestion-item flex justify-between items-center px-4 py-2 text-cyan-200 hover:bg-cyan-500/20 cursor-pointer"
          >
            <span class="suggestion-text font-mono">{tag}</span>
            <span class="suggestion-hint text-cyan-400 text-xs">existing</span>
          </button>
        <% end %>
        <%= if @allow_new_tags and @tag_search not in @suggested_tags and @tag_search != "" do %>
          <button
            type="button"
            phx-click="add_new_tag"
            phx-value-tag={@tag_search}
            phx-target={@myself}
            class="suggestion-item create-suggestion flex items-center gap-2 px-4 py-2 text-cyan-200 hover:bg-cyan-500/20 cursor-pointer"
          >
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 24 24"
              fill="currentColor"
              class="w-5 h-5 text-cyan-400"
            >
              <path d="M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z" />
            </svg>
            <span>Create "{@tag_search}"</span>
          </button>
        <% end %>
      </div>

      <input type="hidden" name="post[tags]" value={Enum.join(@selected_tags, ",")} />
    </div>
    """
  end

  @impl true
  def handle_event("search_tags", %{"value" => search_term}, socket) do
    suggested_tags =
      socket.assigns.all_tags
      |> Enum.filter(&String.contains?(String.downcase(&1), String.downcase(search_term)))
      |> Enum.reject(&(&1 in socket.assigns.selected_tags))
      |> Enum.take(5)

    {:noreply,
     socket
     |> assign(:tag_search, search_term)
     |> assign(:suggested_tags, suggested_tags)
     |> assign(:show_suggestions, true)}
  end

  @impl true
  def handle_event("show_tag_suggestions", _params, socket) do
    {:noreply, assign(socket, :show_suggestions, true)}
  end

  @impl true
  def handle_event("hide_tag_suggestions", _params, socket) do
    Process.send_after(self(), {:hide_suggestions, socket.assigns.id}, 200)
    {:noreply, socket}
  end

  @impl true
  def handle_event("select_first_tag", %{"key" => "Enter"}, socket) do
    case socket.assigns.suggested_tags do
      [tag | _] ->
        if tag in socket.assigns.all_tags do
          selected_tags = [tag | socket.assigns.selected_tags] |> Enum.uniq()

          socket =
            socket
            |> assign(:selected_tags, selected_tags)
            |> assign(:tag_search, "")
            |> assign(:suggested_tags, [])
            |> assign(:show_suggestions, false)
            |> notify_parent()

          {:noreply, socket}
        else
          {:noreply, socket}
        end

      _ ->
        # Allow adding new tag on Enter only if allow_new_tags is true
        if socket.assigns.allow_new_tags and socket.assigns.tag_search != "" do
          tag = socket.assigns.tag_search
          all_tags = [tag | socket.assigns.all_tags] |> Enum.uniq()
          selected_tags = [tag | socket.assigns.selected_tags] |> Enum.uniq()

          socket =
            socket
            |> assign(:all_tags, all_tags)
            |> assign(:selected_tags, selected_tags)
            |> assign(:tag_search, "")
            |> assign(:suggested_tags, [])
            |> assign(:show_suggestions, false)
            |> notify_parent()

          {:noreply, socket}
        else
          {:noreply, socket}
        end
    end
  end

  def handle_event("select_first_tag", _, socket), do: {:noreply, socket}

  @impl true
  def handle_event("add_existing_tag", %{"tag" => tag}, socket) do
    if tag in socket.assigns.all_tags do
      selected_tags = [tag | socket.assigns.selected_tags] |> Enum.uniq()

      socket =
        socket
        |> assign(:selected_tags, selected_tags)
        |> assign(:tag_search, "")
        |> assign(:suggested_tags, [])
        |> assign(:show_suggestions, false)
        |> notify_parent()

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("add_new_tag", %{"tag" => tag}, socket) when byte_size(tag) > 0 do
    if socket.assigns.allow_new_tags do
      all_tags = [tag | socket.assigns.all_tags] |> Enum.uniq()
      selected_tags = [tag | socket.assigns.selected_tags] |> Enum.uniq()

      socket =
        socket
        |> assign(:all_tags, all_tags)
        |> assign(:selected_tags, selected_tags)
        |> assign(:tag_search, "")
        |> assign(:suggested_tags, [])
        |> assign(:show_suggestions, false)
        |> notify_parent()

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  def handle_event("add_new_tag", _, socket), do: {:noreply, socket}

  @impl true
  def handle_event("remove_tag", %{"tag" => tag}, socket) do
    selected_tags = List.delete(socket.assigns.selected_tags, tag)

    socket =
      socket
      |> assign(:selected_tags, selected_tags)
      |> notify_parent()

    {:noreply, socket}
  end

  def handle_info({:hide_suggestions, _}, socket) do
    {:noreply, socket}
  end

  defp notify_parent(socket) do
    send(
      socket.assigns[:parent_pid] || self(),
      {__MODULE__, :tags_updated, socket.assigns.selected_tags}
    )

    socket
  end
end
