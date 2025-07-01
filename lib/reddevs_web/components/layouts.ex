defmodule ReddevsWeb.Layouts do
  @moduledoc """
  This module holds different layouts used by your application.

  See the `layouts` directory for all templates available.
  The "root" layout is a skeleton rendered as part of the
  application router. The "app" layout is rendered as component
  in regular views and live views.
  """
  use ReddevsWeb, :html

  embed_templates "layouts/*"

  @doc """
  Renders the app layout

  ## Examples

      <Layouts.app flash={@flash} current_user={@current_user}>
        <h1>Content</h1>
      </Layout.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :current_user, :map,
    default: nil,
    doc: "the current user"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="min-h-screen flex flex-col">
      <Layouts.menu current_user={@current_user} />

      <div class="cyberpunk-bg w-full"></div>

      <main class="px-4 pb-10 py-8 sm:px-6 lg:px-8 flex-grow">
        <div class="mx-auto max-w-7xl space-y-4">
          {render_slot(@inner_block)}
        </div>
      </main>

      <div class="cyber-footer">
        <div class="footer-content">
          <span>REDDEVS COMMUNITY</span>
          <span>•</span>
          <span>#{DateTime.utc_now().year}</span>
        </div>
      </div>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  def menu(assigns) do
    ~H"""
    <header class="cyber-header">
      <div class="logo-container">
        <a href={~p"/"} class="logo-link">
          <div class="logo glitch" data-text="REDDEVS">
            <span>R</span>
            <span>E</span>
            <span>D</span>
            <span class="neon-accent">D</span>
            <span class="neon-accent">E</span>
            <span>V</span>
            <span>S</span>
            <span class="pixel-cursor">_</span>
          </div>
        </a>
      </div>

      <nav class="cyber-nav">
        <div class="nav-links">
          <a href={~p"/posts"} class="nav-link">
            <span class="link-text">Posts</span>
            <span class="link-underline"></span>
          </a>
          <a href={~p"/articles"} class="nav-link">
            <span class="link-text">Articles</span>
            <span class="link-underline"></span>
          </a>
        </div>

        <hr class="mx-4" />

        <%!-- <div class="terminal-search">
          <input type="text" placeholder="$> search posts..." class="search-input" />
          <div class="terminal-cursor"></div>
          <button class="search-button">
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor">
              <path d="M15.5 14h-.79l-.28-.27a6.5 6.5 0 001.48-5.34c-.47-2.78-2.79-5-5.59-5.34a6.505 6.505 0 00-7.27 7.27c.34 2.8 2.56 5.12 5.34 5.59a6.5 6.5 0 005.34-1.48l.27.28v.79l4.25 4.25c.41.41 1.08.41 1.49 0 .41-.41.41-1.08 0-1.49L15.5 14zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z" />
            </svg>
          </button>
        </div> --%>
      </nav>

      <div class="user-actions z-10">
        <div class="dropdown mx-2 dropdown-center">
          <div tabindex="0" role="button" class="create-post-btn w-full relative overflow-hidden">
            <span class="flex items-center gap-2 px-4 py-2.5 z-10 relative">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                class="h-5 w-5 text-cyan-300 neon-icon"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
              >
                <path stroke-linecap="round" stroke-linejoin="round" d="M12 4v16m8-8H4" />
              </svg>
              <span class="font-bold tracking-wider">CREATE</span>
            </span>

            <div class="absolute inset-0 bg-gradient-to-r from-cyan-600/30 to-purple-600/30 group-hover:opacity-100 opacity-0 transition-opacity duration-500">
            </div>

            <div class="absolute -inset-1 bg-cyan-400/20 rounded-lg blur-sm group-hover:opacity-100 opacity-0 transition-opacity duration-500">
            </div>

            <div class="absolute top-0 left-0 w-3 h-3 border-t border-l border-cyan-400 opacity-70">
            </div>
            <div class="absolute top-0 right-0 w-3 h-3 border-t border-r border-cyan-400 opacity-70">
            </div>
            <div class="absolute bottom-0 left-0 w-3 h-3 border-b border-l border-cyan-400 opacity-70">
            </div>
            <div class="absolute bottom-0 right-0 w-3 h-3 border-b border-r border-cyan-400 opacity-70">
            </div>
          </div>

          <ul
            tabindex="0"
            class="mt-2 dropdown-content menu bg-gray-900 border border-cyan-500/30 rounded-box z-50 w-52 p-2 shadow-2xl shadow-cyan-500/20 transform transition-all duration-300 origin-top scale-95 opacity-0 group-hover:scale-100 group-hover:opacity-100"
          >
            <div class="absolute inset-0 bg-[url('data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHdpZHRoPSIxMDAlIiBoZWlnaHQ9IjEwMCUiPjxyZWN0IHdpZHRoPSIxMDAlIiBoZWlnaHQ9IjEwMCUiIGZpbGw9IiMwMDAiIGZpbGwtb3BhY2l0eT0iMC45Ii8+PHBhdGggZD0iTTAgMC40TDUwIDAuNEwxMDAgMC40IiBzdHJva2U9IiMwMGFhZmYiIHN0cm9rZS13aWR0aD0iMC41IiBzdHJva2UtZGFzaGFycmF5PSI1LDUiIGZpbGw9Im5vbmUiLz48L3N2Zz4=')] opacity-10">
            </div>
            <div class="absolute inset-0 bg-gradient-to-b from-cyan-500/5 to-purple-500/5 rounded-box">
            </div>

            <li class="relative overflow-hidden my-1 first:mt-0 last:mb-0">
              <a
                href="/articles/new"
                class="flex items-center gap-3 px-4 py-3 text-cyan-100 hover:text-white bg-gray-800/50 hover:bg-gray-700/60 backdrop-blur-md border border-gray-700/50 hover:border-cyan-400/40 rounded-lg transition-all duration-300 group/item"
              >
                <div class="w-8 h-8 flex items-center justify-center bg-cyan-900/30 rounded-full border border-cyan-500/30">
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-4 w-4 text-cyan-400"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z"
                    />
                  </svg>
                </div>
                <div>
                  <span class="font-medium">New Article</span>
                  <div class="text-xs text-gray-400 mt-0.5">Technical documentation</div>
                </div>
                <div class="ml-auto w-2 h-2 bg-cyan-400 rounded-full animate-ping group-hover/item:animate-none">
                </div>
              </a>
            </li>

            <%!-- <li class="relative overflow-hidden my-1 first:mt-0 last:mb-0">
              <a
                href="/articles/new"
                class="flex items-center gap-3 px-4 py-3 text-cyan-100 hover:text-white bg-gray-800/50 hover:bg-gray-700/60 backdrop-blur-md border border-gray-700/50 hover:border-purple-400/40 rounded-lg transition-all duration-300 group/item"
              >
                <div class="w-8 h-8 flex items-center justify-center bg-purple-900/30 rounded-full border border-purple-500/30">
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-4 w-4 text-purple-400"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"
                    />
                  </svg>
                </div>
                <div>
                  <span class="font-medium">New Video</span>
                  <div class="text-xs text-gray-400 mt-0.5">Tutorial or review</div>
                </div>
                <div class="ml-auto w-2 h-2 bg-purple-400 rounded-full animate-ping group-hover/item:animate-none">
                </div>
              </a>
            </li> --%>

            <li class="relative overflow-hidden my-1 first:mt-0 last:mb-0">
              <a
                href="/posts/new"
                class="flex items-center gap-3 px-4 py-3 text-cyan-100 hover:text-white bg-gray-800/50 hover:bg-gray-700/60 backdrop-blur-md border border-gray-700/50 hover:border-pink-400/40 rounded-lg transition-all duration-300 group/item"
              >
                <div class="w-8 h-8 flex items-center justify-center bg-pink-900/30 rounded-full border border-pink-500/30">
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    class="h-4 w-4 text-pink-400"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M7 4v16M17 4v16M3 8h4m10 0h4M3 12h18M3 16h4m10 0h4M4 20h16a1 1 0 001-1V5a1 1 0 00-1-1H4a1 1 0 00-1 1v14a1 1 0 001 1z"
                    />
                  </svg>
                </div>
                <div>
                  <span class="font-medium">New Post</span>
                  <div class="text-xs text-gray-400 mt-0.5">Short announcement</div>
                </div>
                <div class="ml-auto w-2 h-2 bg-pink-400 rounded-full animate-ping group-hover/item:animate-none">
                </div>
              </a>
            </li>

            <div class="border-t border-gray-800/50 my-2 mx-2"></div>

            <li>
              <a
                href="/user/settings"
                class="flex items-center gap-3 px-4 py-3 text-gray-400 hover:text-cyan-200 bg-gray-900/50 hover:bg-gray-800/60 rounded-lg transition-colors duration-300"
              >
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  class="h-4 w-4"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"
                  />
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"
                  />
                </svg>
                <span>More options...</span>
              </a>
            </li>
          </ul>
        </div>

        <div class="user-menu">
          <%= if not is_nil(@current_user) do %>
            <button class="user-avatar">
              <img
                src={@current_user.profile_image}
                class="avatar-initial w-full h-full rounded-full object-cover"
              />
            </button>
          <% else %>
            <button class="user-avatar">
              <div class="avatar-initial">U</div>
            </button>
          <% end %>

          <%= if @current_user do %>
            <div class="dropdown-menu">
              <.link href={"/user/#{@current_user.username}"} class="dropdown-item">
                <.icon name="hero-user-circle" /> Profile
              </.link>
              <.link href="/user/settings" class="dropdown-item">
                <.icon name="hero-cog-6-tooth" /> Settings
              </.link>

              <button class="dropdown-item w-full" onclick="logout_modal.showModal()">
                <.icon name="hero-arrow-right-on-rectangle" /> Sign out
              </button>
            </div>
          <% else %>
            <div class="dropdown-menu">
              <.link href="/sign-in" class="dropdown-item">
                <.icon name="hero-user-plus" /> Авторизация
              </.link>
            </div>
          <% end %>
        </div>
      </div>

      <button class="mobile-menu-btn">
        <div class="menu-bar top"></div>
        <div class="menu-bar middle"></div>
        <div class="menu-bar bottom"></div>
      </button>
    </header>
    <dialog
      id="logout_modal"
      class="absolute right-0 daisy-modal  bg-gray-900 bg-opacity-80 backdrop-blur-sm"
    >
      <div class="  top-0 bottom-0 daisy-modal-middle bg-gray-900 border-2 border-cyan-500
                            p-8 max-w-md text-cyan-100 shadow-[0_0_30px_rgba(34,211,238,0.5)]
                            relative overflow-hidden font-mono">
        <div class=" h-0.5 bg-cyan-500 animate-scanline"></div>

        <h3 class="text-2xl font-bold text-cyan-300 mb-4 flex items-center">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            class="h-6 w-6 mr-2 text-cyan-400"
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"
            />
          </svg>
          Подтверждение выхода
        </h3>

        <p class="text-lg mb-6">Вы точно уверены что хотите выйти из системы?</p>

        <div class="flex justify-end space-x-4">
          <form method="dialog">
            <button class="px-6 py-2 border-2 border-gray-500 hover:border-gray-300
                                    bg-gray-800 hover:bg-gray-700 text-gray-300 transition-colors">
              Отмена
            </button>
          </form>

          <a
            href="/sign-out"
            class="cyberpunk-btn bg-red-900 text-red-100 border-2 border-red-400 px-6 py-2
                             hover:bg-red-800 hover:text-white hover:shadow-[0_0_15px_rgba(239,68,68,0.5)]
                             transition-all relative overflow-hidden"
          >
            <span class="relative z-10">Да, выйти</span>
            <span class="absolute inset-0 bg-gradient-to-r from-red-500/10 to-red-900/10
                                  opacity-0 hover:opacity-100 transition-opacity duration-300">
            </span>
          </a>
        </div>

        <div class="absolute top-2 left-2 w-3 h-3 border-t-2 border-l-2 border-cyan-400"></div>
        <div class="absolute top-2 right-2 w-3 h-3 border-t-2 border-r-2 border-cyan-400"></div>
        <div class="absolute bottom-2 left-2 w-3 h-3 border-b-2 border-l-2 border-cyan-400"></div>
        <div class="absolute bottom-2 right-2 w-3 h-3 border-b-2 border-r-2 border-cyan-400"></div>
      </div>
    </dialog>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  def banner(assigns) do
    ~H"""
    <div class="neon-header">
      <div class="pixel-title glitch" data-text="REDDEVS">
        <span>RED</span>
        <span class="neon-accent">DEVS</span>
        <span class="pixel-cursor">_</span>
      </div>

      <div class="header-actions hidden">
        <.button navigate={~p"/posts/new"}>
          <.icon name="hero-plus" class="neon-icon" />
          <span class="neon-button-text">CREATE POST</span>
        </.button>
      </div>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "system"})}
        class="flex p-2 cursor-pointer w-1/3"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "light"})}
        class="flex p-2 cursor-pointer w-1/3"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "dark"})}
        class="flex p-2 cursor-pointer w-1/3"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        phx-click={JS.dispatch("phx:set-theme", detail: %{theme: "synthwave"})}
        class="flex p-2 cursor-pointer w-1/3"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
