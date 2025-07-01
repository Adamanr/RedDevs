defmodule ReddevsWeb.AuthController do
  use ReddevsWeb, :controller
  use AshAuthentication.Phoenix.Controller
  require Logger

  def success(conn, activity, user, _token) do
    intent = conn.query_params["intent"] || "unknown"

    Logger.info(
      "Authentication succeeded for activity #{inspect(activity)} with intent #{intent}, user: #{user.id}"
    )

    if is_nil(user.confirmed_at) do
      Logger.debug("User #{user.id} is unconfirmed, redirecting to confirmation page")

      conn
      |> put_flash(:error, "Please confirm your email address to continue.")
      |> redirect(to: ~p"/alerts/confirm_register/#{user.email}")
    else
      return_to = get_session(conn, :return_to) || ~p"/"

      message =
        case {activity, intent} do
          {{:confirm_new_user, :confirm}, _} ->
            "Your email address has now been confirmed"

          {{:password, :reset}, _} ->
            "Your password has successfully been reset"

          {{:github, :authenticate_with_github}, "sign_in"} ->
            "Successfully signed in with GitHub!"

          {{:github, :authenticate_with_github}, "register"} ->
            "Successfully registered with GitHub!"

          _ ->
            "You are now signed in"
        end

      conn
      |> delete_session(:return_to)
      |> store_in_session(user)
      |> assign(:current_user, user)
      |> put_flash(:info, message)
      |> redirect(to: return_to)
    end
  end

  def failure(conn, activity, reason) do
    intent = conn.query_params["intent"] || "unknown"

    Logger.error(
      "Authentication failed for activity #{inspect(activity)} with intent #{intent}: #{inspect(reason)}"
    )

    message =
      case {activity, reason} do
        {{:github, :authenticate_with_github},
         %AshAuthentication.Errors.AuthenticationFailed{
           caused_by: %Ash.Error.Changes.InvalidAttribute{
             field: :email,
             message: message
           }
         }} ->
          Logger.error("Invalid email during GitHub authentication: #{message}")
          "GitHub authentication failed: #{message}"

        {{:github, :authenticate_with_github},
         %AshAuthentication.Errors.AuthenticationFailed{
           caused_by: %Ash.Error.Changes.InvalidChanges{
             message: "Unconfirmed user exists already"
           }
         }} ->
          """
          An unconfirmed account with this email already exists.
          Please confirm your account using the link sent to your email or request a new confirmation.
          """

        {{:github, :authenticate_with_github},
         %AshAuthentication.Errors.AuthenticationFailed{
           caused_by: %Ash.Error.Unknown{
             errors: [%Ash.Error.Unknown.UnknownError{error: %Postgrex.Error{message: message}}]
           }
         }} ->
          Logger.error("Postgrex error during GitHub authentication: #{message}")

          "GitHub authentication failed due to a database error. Please try again or contact support."

        {{:github, :authenticate_with_github}, _} ->
          "GitHub authentication failed. Please try again or use another sign-in method."

        {_,
         %AshAuthentication.Errors.AuthenticationFailed{
           caused_by: %Ash.Error.Forbidden{
             errors: [%AshAuthentication.Errors.CannotConfirmUnconfirmedUser{}]
           }
         }} ->
          """
          You have already signed in another way, but have not confirmed your account.
          You can confirm your account using the link we sent to you, or by resetting your password.
          """

        {_, %AshAuthentication.Errors.MissingSecret{path: path}} ->
          "Authentication failed: missing secret for #{inspect(path)}"

        _ ->
          "Incorrect email or password"
      end

    conn
    |> put_flash(:error, message)
    |> redirect(to: ~p"/sign-in")
  end

  def sign_out(conn, _params) do
    return_to = get_session(conn, :return_to) || ~p"/"

    conn
    |> clear_session(:reddevs)
    |> put_flash(:info, "You are now signed out")
    |> redirect(to: return_to)
  end
end
