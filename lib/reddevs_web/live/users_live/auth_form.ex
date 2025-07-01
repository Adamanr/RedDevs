defmodule ReddevsWeb.UserLive.AuthForm do
  use ReddevsWeb, :live_component

  alias AshPhoenix.Form
  alias ReddevsWeb.Helpers

  @impl true
  def update(assigns, socket) do
    auth_intent = if assigns.is_register?, do: :register, else: :sign_in

    socket =
      socket
      |> assign(assigns)
      |> assign(trigger_action: false)
      |> assign(form_errors: %{})
      |> assign(form_map_errors: %{})
      |> assign(auth_intent: auth_intent)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"user" => params}, socket) do
    form = Form.validate(socket.assigns.form, params, errors: false)
    form_map_errors = form_errors_to_map(Form.errors(form))
    form_errors = Enum.reverse(Form.errors(form))

    socket =
      socket
      |> assign(
        form: form,
        form_map_errors: form_map_errors,
        form_errors: form_errors,
        trigger_action: false
      )

    {:noreply, socket}
  end

  @impl true
  def handle_event("submit", %{"user" => params}, socket) do
    form = Form.validate(socket.assigns.form, params, errors: true)
    form_map_errors = form_errors_to_map(Form.errors(form))
    form_errors = Enum.reverse(Form.errors(form))

    socket =
      if form.valid? do
        socket
        |> assign(
          form: form,
          form_errors: form_errors,
          form_map_errors: form_map_errors,
          trigger_action: true
        )
      else
        socket
        |> assign(
          form: form,
          form_errors: form_errors,
          form_map_errors: form_map_errors,
          trigger_action: false
        )
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("set-auth-intent", %{"auth_intent" => auth_intent}, socket) do
    {:noreply, assign(socket, :auth_intent, String.to_atom(auth_intent))}
  end

  defp form_errors_to_map(errors) do
    Enum.reduce(errors, %{exactly_handled?: false, seen_messages: MapSet.new(), map: %{}}, fn
      %Ash.Error.Changes.InvalidChanges{vars: %{keys: keys, exactly: exactly}} = _error,
      %{exactly_handled?: false, seen_messages: seen, map: map} = acc
      when exactly == 4 ->
        message = humanize_exactly_error(keys, exactly)

        if MapSet.member?(seen, message) do
          acc
        else
          %{
            acc
            | exactly_handled?: true,
              seen_messages: MapSet.put(seen, message),
              map: Map.put(map, :base, [message | Map.get(map, :base, [])])
          }
        end

      %Ash.Error.Changes.InvalidChanges{vars: %{keys: _, exactly: _}}, acc ->
        acc

      error, %{seen_messages: seen, map: map} = acc ->
        field = get_error_field(error)
        message = humanize_error(error, field)

        if MapSet.member?(seen, message) do
          acc
        else
          updated_map = Map.update(map, field, [message], &[message | &1])

          %{
            acc
            | seen_messages: MapSet.put(seen, message),
              map: updated_map
          }
        end
    end)
    |> Map.get(:map)
  end

  defp get_error_field(%Ash.Error.Changes.Required{field: field}), do: field
  defp get_error_field(%Ash.Error.Changes.InvalidChanges{fields: [field]}), do: field
  defp get_error_field(%{field: field}) when not is_nil(field), do: field
  defp get_error_field(_), do: :base

  defp humanize_error(%Ash.Error.Changes.InvalidChanges{message: "does not match"}, field) do
    "does not match #{field}"
  end

  defp humanize_error(
         %Ash.Error.Changes.InvalidChanges{
           message: "length must be greater than or equal to %{length}",
           vars: %{length: length}
         },
         field
       ) do
    "#{field} length must be greater than or equal to #{length}"
  end

  defp humanize_error(%Ash.Error.Changes.Required{}, _field) do
    "is required"
  end

  defp humanize_error(%{message: message}, _field) when is_binary(message), do: message
  defp humanize_error(error, _field), do: inspect(error)

  defp humanize_exactly_error(keys, 4) do
    fields = Enum.map(keys, &to_string/1) |> Enum.join(",")
    "exactly 4 of #{fields} must be present"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="matrix-bg"></div>
      <div class="mx-auto px-4 max-w-2xl">
        <div class="cyber-card neon-border p-8">
          <div class="text-center mb-10">
            <%= if @is_register? do %>
              <h1 class="cyber-title text-4xl font-bold tracking-wider">
                <span class="neon-blue-text">CREATE</span>
                <span class="neon-pink-text">YOUR</span>
                <span class="neon-green-text">HACKER</span>
                <span class="neon-purple-text">PROFILE</span>
              </h1>
            <% else %>
              <h1 class="cyber-title text-4xl font-bold tracking-wider">
                <span class="neon-green-text">SYSTEM</span>
                <span class="neon-blue-text">ACCESS</span>
              </h1>
            <% end %>
            <div class="scanline h-1 w-full my-4"></div>
            <p class="text-cyber-gray">{@cta_sub}</p>
          </div>

          <.form
            :let={f}
            for={@form}
            phx-submit="submit"
            phx-change="validate"
            phx-trigger-action={@trigger_action}
            phx-target={@myself}
            action={@action}
            method="POST"
            id="login-form"
            class="space-y-6"
            novalidate
          >
            <%= if @form_errors != %{} and @form_errors != [] do %>
              <div class="bg-red-900/30 border border-red-600 rounded-lg p-5 mb-6 shadow-neon-red">
                <p class="text-red-300 text-sm font-mono uppercase tracking-wide mb-2">
                  System Alert: Input Error
                </p>
                <%= for {key, message} <- @form_errors do %>
                  <p
                    :if={key != :accepted_code_of_conduct and key != :accepted_terms_and_conditions}
                    class="text-red-200 text-sm font-mono"
                  >
                    > #Ошибка: {Helpers.register_convert(message, key)}
                  </p>
                <% end %>
              </div>
            <% end %>

            <div class="input-group">
              <label class="cyber-label">
                <span class="neon-pink-text">EMAIL</span>
                <div class="mt-2">
                  <input
                    type="email"
                    name={f[:email].name}
                    value={Phoenix.HTML.Form.input_value(f, :email) || ""}
                    class={"cyber-input #{if @form_errors[:email], do: "border-red-500"}"}
                    placeholder="user@neural.network"
                    required
                    autofocus
                  />
                  <div class="terminal-cursor"></div>
                </div>
                <%= if @form_errors[:email] do %>
                  <%= for message <- List.wrap(@form_errors[:email]) do %>
                    <p class="text-red-400 text-xs mt-1">
                      > #Ошибка: {Helpers.register_convert(message)}
                    </p>
                  <% end %>
                <% end %>
              </label>
            </div>

            <%= if @is_register? do %>
              <!-- Username field -->
              <div class="input-group">
                <label class="cyber-label">
                  <span class="neon-green-text">USERNAME</span>
                  <div class="mt-2">
                    <input
                      type="text"
                      name={f[:username].name}
                      value={Phoenix.HTML.Form.input_value(f, :username) || ""}
                      class={"cyber-input #{if @form_errors[:username], do: "border-red-500"}"}
                      placeholder="user"
                      required
                    />
                    <div class="terminal-cursor"></div>
                  </div>
                  <%= if @form_errors[:username] do %>
                    <%= for message <- List.wrap(@form_errors[:username]) do %>
                      <p class="text-red-400 text-xs mt-1">
                        > #Ошибка: {Helpers.register_convert(message)}
                      </p>
                    <% end %>
                  <% end %>
                </label>
              </div>
            <% end %>
            
    <!-- Password field -->
            <div class="input-group">
              <label class="cyber-label">
                <span class="neon-purple-text">PASSWORD</span>
                <div class="mt-2">
                  <input
                    type="password"
                    name={f[:password].name}
                    value={Phoenix.HTML.Form.input_value(f, :password) || ""}
                    class={"cyber-input #{if @form_errors[:password], do: "border-red-500"}"}
                    placeholder="••••••••"
                    required
                  />
                  <div class="terminal-cursor"></div>
                </div>
                <%= if @form_errors[:password] do %>
                  <%= for message <- List.wrap(@form_errors[:password]) do %>
                    <p class="text-red-400 text-xs mt-1">
                      > #Ошибка: {Helpers.register_convert(message)}
                    </p>
                  <% end %>
                <% end %>
              </label>
            </div>

            <%= if @is_register? do %>
              <div class="input-group">
                <label class="cyber-label">
                  <span class="neon-purple-text">CONFIRM PASSWORD</span>
                  <div class="mt-2">
                    <input
                      type="password"
                      name={f[:password_confirmation].name}
                      class={"cyber-input #{if @form_errors[:password_confirmation], do: "border-red-500"}"}
                      value={Phoenix.HTML.Form.input_value(f, :password_confirmation) || ""}
                      placeholder="••••••••"
                      required
                    />
                    <div class="terminal-cursor"></div>
                  </div>
                  <%= if @form_errors[:password_confirmation] do %>
                    <%= for message <- List.wrap(@form_errors[:password_confirmation]) do %>
                      <p class="text-red-400 text-xs mt-1">{Helpers.register_convert(message)}</p>
                    <% end %>
                  <% end %>
                </label>
              </div>

              <div class="input-group">
                <label class="cyber-label flex items-center space-x-3">
                  <input
                    type="checkbox"
                    name={f[:accepted_code_of_conduct].name}
                    class="cyber-checkbox"
                    value="true"
                    checked
                  />
                  <span class="neon-blue-text">I accept the Code of Conduct</span>
                </label>
              </div>

              <div class="input-group">
                <label class="cyber-label flex items-center space-x-3">
                  <input
                    type="checkbox"
                    name={f[:accepted_terms_and_conditions].name}
                    class="cyber-checkbox"
                    value="true"
                    checked
                  />
                  <span class="neon-blue-text">I accept Terms and Conditions</span>
                </label>
              </div>
            <% else %>
              <div class="flex justify-between items-center pt-3">
                <label class="cyber-label flex items-center space-x-2">
                  <input type="checkbox" name="remember_me" class="cyber-checkbox" />
                  <span class="text-cyber-gray text-sm">Remember this terminal</span>
                </label>

                <.link href="/password-reset" class="text-sm neon-blue-link hover:underline">
                  Access code lost?
                </.link>
              </div>
            <% end %>

            <div class="pt-8">
              <button
                type="submit"
                class="cyber-button w-full py-4 text-lg font-bold tracking-wider"
                phx-disable-with="Authenticating..."
              >
                <span class="neon-text">{@label_button}</span>
                <span class="pulse-dot"></span>
              </button>
            </div>

            <div class="text-center pt-8">
              <p class="text-cyber-gray">
                <.link href={@alternative_path} class="neon-green-link hover:underline ml-1">
                  {@alternative}
                </.link>
              </p>
            </div>

            <%= if !@is_register? do %>
              <div class="relative flex items-center pt-6">
                <div class="flex-grow border-t border-cyber-blue opacity-30"></div>
                <span class="flex-shrink mx-4 text-cyber-gray">OR</span>
                <div class="flex-grow border-t border-cyber-blue opacity-30"></div>
              </div>

              <div class="grid grid-cols-2 gap-4 pt-4">
                <a
                  href={
                    if @is_register?,
                      do: "/auth/user/google",
                      else: "/auth/user/google?intent=sign_in"
                  }
                  class="cyber-alt-button flex items-center justify-center gap-2"
                >
                  <svg
                    viewBox="-0.5 0 48 48"
                    version="1.1"
                    xmlns="http://www.w3.org/2000/svg"
                    xmlns:xlink="http://www.w3.org/1999/xlink"
                    class="w-5 h-5 text-[#5865F2]"
                    fill="currentColor"
                  >
                    <g id="SVGRepo_bgCarrier" stroke-width="0"></g>
                    <g id="SVGRepo_tracerCarrier" stroke-linecap="round" stroke-linejoin="round"></g>
                    <g id="SVGRepo_iconCarrier">
                      <title>Google-color</title>

                      <desc>Created with Sketch.</desc>

                      <defs></defs>

                      <g id="Icons" stroke="none" stroke-width="1" fill="none" fill-rule="evenodd">
                        <g id="Color-" transform="translate(-401.000000, -860.000000)">
                          <g id="Google" transform="translate(401.000000, 860.000000)">
                            <path
                              d="M9.82727273,24 C9.82727273,22.4757333 10.0804318,21.0144 10.5322727,19.6437333 L2.62345455,13.6042667 C1.08206818,16.7338667 0.213636364,20.2602667 0.213636364,24 C0.213636364,27.7365333 1.081,31.2608 2.62025,34.3882667 L10.5247955,28.3370667 C10.0772273,26.9728 9.82727273,25.5168 9.82727273,24"
                              id="Fill-1"
                              fill="#FBBC05"
                            >
                            </path>

                            <path
                              d="M23.7136364,10.1333333 C27.025,10.1333333 30.0159091,11.3066667 32.3659091,13.2266667 L39.2022727,6.4 C35.0363636,2.77333333 29.6954545,0.533333333 23.7136364,0.533333333 C14.4268636,0.533333333 6.44540909,5.84426667 2.62345455,13.6042667 L10.5322727,19.6437333 C12.3545909,14.112 17.5491591,10.1333333 23.7136364,10.1333333"
                              id="Fill-2"
                              fill="#EB4335"
                            >
                            </path>

                            <path
                              d="M23.7136364,37.8666667 C17.5491591,37.8666667 12.3545909,33.888 10.5322727,28.3562667 L2.62345455,34.3946667 C6.44540909,42.1557333 14.4268636,47.4666667 23.7136364,47.4666667 C29.4455,47.4666667 34.9177955,45.4314667 39.0249545,41.6181333 L31.5177727,35.8144 C29.3995682,37.1488 26.7323182,37.8666667 23.7136364,37.8666667"
                              id="Fill-3"
                              fill="#34A853"
                            >
                            </path>

                            <path
                              d="M46.1454545,24 C46.1454545,22.6133333 45.9318182,21.12 45.6113636,19.7333333 L23.7136364,19.7333333 L23.7136364,28.8 L36.3181818,28.8 C35.6879545,31.8912 33.9724545,34.2677333 31.5177727,35.8144 L39.0249545,41.6181333 C43.3393409,37.6138667 46.1454545,31.6490667 46.1454545,24"
                              id="Fill-4"
                              fill="#4285F4"
                            >
                            </path>
                          </g>
                        </g>
                      </g>
                    </g>
                  </svg>
                  <span>Google</span>
                </a>

                <a
                  href={
                    if @is_register?,
                      do: "/auth/user/github",
                      else: "/auth/user/github?intent=sign_in"
                  }
                  class="cyber-alt-button flex items-center justify-center gap-2"
                >
                  <svg
                    viewBox="0 0 20 20"
                    version="1.1"
                    xmlns="http://www.w3.org/2000/svg"
                    xmlns:xlink="http://www.w3.org/1999/xlink"
                    class="w-5 h-5 text-[#333]"
                    fill="currentColor"
                  >
                    <g id="SVGRepo_bgCarrier" stroke-width="0"></g>
                    <g id="SVGRepo_tracerCarrier" stroke-linecap="round" stroke-linejoin="round"></g>
                    <g id="SVGRepo_iconCarrier">
                      <title>github [#142]</title>

                      <desc>Created with Sketch.</desc>

                      <defs></defs>

                      <g id="Page-1" stroke="none" stroke-width="1" fill="none" fill-rule="evenodd">
                        <g
                          id="Dribbble-Light-Preview"
                          transform="translate(-140.000000, -7559.000000)"
                          fill="#000000"
                        >
                          <g id="icons" transform="translate(56.000000, 160.000000)">
                            <path
                              d="M94,7399 C99.523,7399 104,7403.59 104,7409.253 C104,7413.782 101.138,7417.624 97.167,7418.981 C96.66,7419.082 96.48,7418.762 96.48,7418.489 C96.48,7418.151 96.492,7417.047 96.492,7415.675 C96.492,7414.719 96.172,7414.095 95.813,7413.777 C98.04,7413.523 100.38,7412.656 100.38,7408.718 C100.38,7407.598 99.992,7406.684 99.35,7405.966 C99.454,7405.707 99.797,7404.664 99.252,7403.252 C99.252,7403.252 98.414,7402.977 96.505,7404.303 C95.706,7404.076 94.85,7403.962 94,7403.958 C93.15,7403.962 92.295,7404.076 91.497,7404.303 C89.586,7402.977 88.746,7403.252 88.746,7403.252 C88.203,7404.664 88.546,7405.707 88.649,7405.966 C88.01,7406.684 87.619,7407.598 87.619,7408.718 C87.619,7412.646 89.954,7413.526 92.175,7413.785 C91.889,7414.041 91.63,7414.493 91.54,7415.156 C90.97,7415.418 89.522,7415.871 88.63,7414.304 C88.63,7414.304 88.101,7413.319 87.097,7413.247 C87.097,7413.247 86.122,7413.234 87.029,7413.87 C87.029,7413.87 87.684,7414.185 88.139,7415.37 C88.139,7415.37 88.726,7417.2 91.508,7416.58 C91.513,7417.437 91.522,7418.245 91.522,7418.489 C91.522,7418.76 91.338,7419.077 90.839,7418.982 C86.865,7417.627 84,7413.783 84,7409.253 C84,7403.59 88.478,7399 94,7399"
                              id="github-[#142]"
                            >
                            </path>
                          </g>
                        </g>
                      </g>
                    </g>
                  </svg>

                  <span>GitHub</span>
                </a>
              </div>
            <% end %>
          </.form>
        </div>
      </div>
    </div>
    """
  end
end
