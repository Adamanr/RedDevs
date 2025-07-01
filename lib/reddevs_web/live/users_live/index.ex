defmodule ReddevsWeb.UserLive.Index do
  use ReddevsWeb, :live_view

  alias Reddevs.Accounts
  alias Reddevs.Accounts.User
  alias AshPhoenix.Form

  @impl true
  def mount(_, _, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :register, _params) do
    socket
    |> assign(:form_id, "sign-up-form")
    |> assign(:cta, "CREATE YOUR PROFILE")
    |> assign(:cta_sub, "Join the neural network of elite developers")
    |> assign(:label_button, "ACTIVATE ACCOUNT")
    |> assign(:alternative_path, ~p"/sign-in")
    |> assign(:alternative, "Already part of the network? Access your console")
    |> assign(:action, ~p"/auth/user/password/register")
    |> assign(
      :form,
      Form.for_create(User, :register_with_password, api: Accounts, as: "user")
    )
  end

  defp apply_action(socket, :sign_in, _params) do
    socket
    |> assign(:form_id, "sign-in-form")
    |> assign(:cta, "SYSTEM ACCESS")
    |> assign(:cta_sub, "Authenticate to enter the neural network")
    |> assign(:label_button, "INITIATE ACCESS")
    |> assign(:alternative_path, ~p"/register")
    |> assign(:alternative, "New to the network? Activate your profile")
    |> assign(:action, ~p"/auth/user/password/sign_in")
    |> assign(
      :form,
      Form.for_action(User, :sign_in_with_password, api: Accounts, as: "user")
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="auth-page">
      <Layouts.app flash={@flash}>
        <div class="matrix-bg"></div>

        <.live_component
          module={ReddevsWeb.UserLive.AuthForm}
          id={@form_id}
          form={@form}
          alternative={@alternative}
          alternative_path={@alternative_path}
          is_register?={@live_action == :register}
          action={@action}
          label_button={@label_button}
          cta={@cta}
          cta_sub={@cta_sub}
        />
      </Layouts.app>
    </div>
    """
  end
end
