defmodule Reddevs.Secrets do
  use AshAuthentication.Secret

  def secret_for(
        [:authentication, :tokens, :signing_secret],
        Reddevs.Accounts.User,
        _opts
      ) do
    Application.fetch_env(:reddevs, :token_signing_secret)
  end

  def secret_for([:authentication, :strategies, :github, :client_id], Reddevs.Accounts.User, _) do
    get_config(:client_id, :github)
  end

  def secret_for([:authentication, :strategies, :github, :redirect_uri], Reddevs.Accounts.User, _) do
    get_config(:redirect_uri, :github)
  end

  def secret_for(
        [:authentication, :strategies, :github, :client_secret],
        Reddevs.Accounts.User,
        _
      ) do
    get_config(:client_secret, :github)
  end

  def secret_for(
        [:authentication, :strategies, :google, :client_id],
        Reddevs.Accounts.User,
        _opts
      ) do
    get_config(:client_id, :google)
  end

  def secret_for(
        [:authentication, :strategies, :google, :redirect_uri],
        Reddevs.Accounts.User,
        _opts
      ) do
    get_config(:redirect_uri, :google)
  end

  def secret_for(
        [:authentication, :strategies, :google, :client_secret],
        Reddevs.Accounts.User,
        _opts
      ) do
    get_config(:client_secret, :google)
  end

  defp get_config(key, provider) do
    secrets =
      :reddevs
      |> Application.get_env(provider, [])
      |> Keyword.fetch(key)

    IO.inspect(secrets, label: "SECRETS")

    secrets
  end
end
