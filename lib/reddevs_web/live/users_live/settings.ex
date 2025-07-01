defmodule ReddevsWeb.UserLive.Settings do
  use ReddevsWeb, :live_view
  alias AshPhoenix.Form

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    profile_form = Form.for_update(user, :update_profile, as: "user", actor: user)
    password_form = Form.for_update(user, :change_password, as: "user", actor: user)

    {:ok,
     socket
     |> assign(:profile_form, to_form(profile_form))
     |> assign(:password_form, to_form(password_form))
     |> assign(:user, user)
     |> assign(:selected_tags, user.currently_learning || [])
     |> assign(:tag_search, "")
     |> assign(:suggested_tags, [])
     |> assign(:show_tag_suggestions, false)}
  end

  @impl true
  def handle_event("validate_profile", %{"user" => params}, socket) do
    params_with_tags = Map.put(params, "currently_learning", socket.assigns.selected_tags)

    profile_form =
      socket.assigns.profile_form
      |> Form.validate(params_with_tags, errors: true)

    {:noreply,
     socket
     |> assign(:profile_form, to_form(profile_form))}
  end

  @impl true
  def handle_event("save_profile", %{"user" => params}, socket) do
    user = socket.assigns.current_user
    params_with_tags = Map.put(params, "currently_learning", socket.assigns.selected_tags)

    case Form.submit(socket.assigns.profile_form,
           params: params_with_tags,
           actor: user
         ) do
      {:ok, updated_user} ->
        profile_form = Form.for_update(updated_user, :update_profile, as: "user", actor: user)

        {:noreply,
         socket
         |> put_flash(:info, "Profile updated successfully!")
         |> assign(:user, updated_user)
         |> assign(:profile_form, to_form(profile_form))}

      {:error, profile_form} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to update profile. Please check your input.")
         |> assign(:profile_form, to_form(profile_form))}
    end
  end

  @impl true
  def handle_event("validate_password", %{"user" => params}, socket) do
    password_form =
      socket.assigns.password_form
      |> Form.validate(params, errors: true)

    {:noreply,
     socket
     |> assign(:password_form, to_form(password_form))}
  end

  @impl true
  def handle_event("save_password", %{"user" => params}, socket) do
    user = socket.assigns.current_user

    case Form.submit(socket.assigns.password_form,
           params: params,
           actor: user
         ) do
      {:ok, updated_user} ->
        password_form = Form.for_update(updated_user, :change_password, as: "user", actor: user)

        {:noreply,
         socket
         |> put_flash(:info, "Password updated successfully!")
         |> assign(:user, updated_user)
         |> assign(:password_form, to_form(password_form))}

      {:error, password_form} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to update password. Please check your input.")
         |> assign(:password_form, to_form(password_form))}
    end
  end

  def handle_event("search_tags", %{"value" => search_term}, socket) do
    all_tags = get_all_skills()

    suggested_tags =
      all_tags
      |> Enum.filter(&String.contains?(String.downcase(&1), String.downcase(search_term)))
      |> Enum.reject(&(&1 in socket.assigns.selected_tags))
      |> Enum.take(5)

    {:noreply,
     socket
     |> assign(:tag_search, search_term)
     |> assign(:suggested_tags, suggested_tags)
     |> assign(:show_tag_suggestions, true)}
  end

  def handle_event("add_existing_tag", %{"tag" => tag}, socket) do
    selected_tags = [tag | socket.assigns.selected_tags] |> Enum.uniq()
    {:noreply, assign(socket, :selected_tags, selected_tags)}
  end

  def handle_event("add_new_tag", %{"tag" => tag}, socket) do
    selected_tags = [tag | socket.assigns.selected_tags] |> Enum.uniq()
    {:noreply, assign(socket, :selected_tags, selected_tags)}
  end

  def handle_event("remove_tag", %{"tag" => tag}, socket) do
    selected_tags = List.delete(socket.assigns.selected_tags, tag)
    {:noreply, assign(socket, :selected_tags, selected_tags)}
  end

  defp get_all_skills do
    [
      "ELIXIR",
      "PHOENIX",
      "LIVEVIEW",
      "ASH",
      "NERVES",
      "AI",
      "BLOCKCHAIN",
      "CYBER_SECURITY",
      "RUST",
      "CRYPTOGRAPHY"
    ]
  end
end
