defmodule ReddevsWeb.PageController do
  use ReddevsWeb, :controller
  require Logger

  def home(conn, _params) do
    redirect(conn, to: "/posts")
  end

  def session_debug(conn, _params) do
    user = conn.assigns[:current_user]
    debug_user = conn.assigns[:debug_current_user]
    session_data = Plug.Conn.get_session(conn)
    cookies = conn.cookies

    auth_key = "ash_authentication:current_user:#{Reddevs.Accounts.User}"
    user_auth_data = Map.get(session_data, auth_key)

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, """
    Session Data: #{inspect(session_data, pretty: true)}

    Auth Key: #{auth_key}
    Auth Data: #{inspect(user_auth_data, pretty: true)}

    Cookies: #{inspect(cookies, pretty: true)}

    Current User: #{if user, do: "#{user.email} (#{user.id})", else: "Not authenticated"}
    Debug User: #{if debug_user, do: "#{debug_user.email} (#{debug_user.id})", else: "Not found"}
    """)
  end
end
