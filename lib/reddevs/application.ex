defmodule Reddevs.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ReddevsWeb.Telemetry,
      Reddevs.Repo,
      {DNSCluster, query: Application.get_env(:reddevs, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Reddevs.PubSub},
      # Start a worker by calling: Reddevs.Worker.start_link(arg)
      # {Reddevs.Worker, arg},
      # Start to serve requests, typically the last entry
      ReddevsWeb.Endpoint,
      {Absinthe.Subscription, ReddevsWeb.Endpoint},
      AshGraphql.Subscription.Batcher,
      {AshAuthentication.Supervisor, [otp_app: :reddevs]}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Reddevs.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ReddevsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
