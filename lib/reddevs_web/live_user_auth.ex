defmodule ReddevsWeb.LiveUserAuth do
  @moduledoc """
  Helpers for authenticating users in LiveViews.
  """

  import Phoenix.Component
  use ReddevsWeb, :verified_routes
  require Logger

  # This is used for nested liveviews to fetch the current user.
  # To use, place the following at the top of that liveview:
  # on_mount {ReddevsWeb.LiveUserAuth, :current_user}
  def on_mount(:current_user, _params, session, socket) do
    Logger.info("LiveUserAuth.on_mount(:current_user) - Session: #{inspect(session)}")
    {:cont, AshAuthentication.Phoenix.LiveSession.assign_new_resources(socket, session)}
  end

  def on_mount(:live_user_optional, _params, session, socket) do
    Logger.info("LiveUserAuth.on_mount(:live_user_optional) - Session: #{inspect(session)}")
    socket = AshAuthentication.Phoenix.LiveSession.assign_new_resources(socket, session)

    if socket.assigns[:current_user] do
      Logger.info(
        "LiveUserAuth: User found in socket.assigns - #{inspect(socket.assigns[:current_user].email)}"
      )

      {:cont, socket}
    else
      Logger.info("LiveUserAuth: No user found in session")
      {:cont, assign(socket, :current_user, nil)}
    end
  end

  def on_mount(:live_user_required, _params, session, socket) do
    Logger.info("LiveUserAuth.on_mount(:live_user_required) - Session: #{inspect(session)}")
    socket = AshAuthentication.Phoenix.LiveSession.assign_new_resources(socket, session)

    if socket.assigns[:current_user] do
      Logger.info(
        "LiveUserAuth: User required and found - #{inspect(socket.assigns[:current_user].email)}"
      )

      {:cont, socket}
    else
      Logger.info("LiveUserAuth: User required but not found, redirecting to sign-in")
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/sign-in")}
    end
  end

  def on_mount(:live_no_user, _params, session, socket) do
    Logger.info("LiveUserAuth.on_mount(:live_no_user) - Session: #{inspect(session)}")
    socket = AshAuthentication.Phoenix.LiveSession.assign_new_resources(socket, session)

    if socket.assigns[:current_user] do
      Logger.info("LiveUserAuth: No user required but found - redirecting to home")
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/")}
    else
      Logger.info("LiveUserAuth: No user required and none found")
      {:cont, assign(socket, :current_user, nil)}
    end
  end
end
