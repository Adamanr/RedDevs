defmodule ReddevsWeb.Router do
  use ReddevsWeb, :router

  use AshAuthentication.Phoenix.Router

  import AshAuthentication.Plug.Helpers

  pipeline :graphql do
    plug :load_from_bearer
    plug :set_actor, :user
    plug AshGraphql.Plug
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ReddevsWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
    plug :set_actor, :user
  end

  scope "/", ReddevsWeb do
    pipe_through :browser

    live "/alerts/confirm_register/:email", AlertLive.RegisterConfirm
    live "/register", UserLive.Index, :register
    live "/sign-in", UserLive.Index, :sign_in
    auth_routes_for Reddevs.Accounts.User, to: AuthController, path: "/auth"

    ash_authentication_live_session :authenticated_routes do
      live "/posts", PostLive.Index, :index
      # live "/posts/:username", PostLive.Index, :index
      live "/posts/new", PostLive.Form, :new
      live "/posts/:slug", PostLive.Show, :show
      live "/posts/:slug/edit", PostLive.Form, :edit
      live "/posts/:slug/show/edit", PostLive.Show, :edit

      live "/articles", ArticleLive.Index, :index
      live "/articles/new", ArticleLive.Form, :new
      live "/articles/:slug", ArticleLive.Show, :show
      live "/articles/:slug/edit", ArticleLive.Form, :edit
      live "/articles/:slug/show/edit", ArticleLive.Show, :edit

      live "/user/settings", UserLive.Settings, :settings
      live "/user/:username", UserLive.Profile, :profile

      # in each liveview, add one of the following at the top of the module:
      #
      # If an authenticated user must be present:
      # on_mount {ReddevsWeb.LiveUserAuth, :live_user_required}
      #
      # If an authenticated user *may* be present:
      # on_mount {ReddevsWeb.LiveUserAuth, :live_user_optional}
      #
      # If an authenticated user must *not* be present:
      # on_mount {ReddevsWeb.LiveUserAuth, :live_no_user}
    end
  end

  scope "/gql" do
    pipe_through [:graphql]

    forward "/playground", Absinthe.Plug.GraphiQL,
      schema: Module.concat(["ReddevsWeb.GraphqlSchema"]),
      socket: Module.concat(["ReddevsWeb.GraphqlSocket"]),
      interface: :simple

    forward "/", Absinthe.Plug, schema: Module.concat(["ReddevsWeb.GraphqlSchema"])
  end

  scope "/", ReddevsWeb do
    pipe_through :browser

    get "/", PageController, :home
    auth_routes AuthController, Reddevs.Accounts.User, path: "/auth"
    sign_out_route AuthController

    # Remove these if you'd like to use your own authentication views
    sign_in_route register_path: "/register",
                  reset_path: "/reset",
                  auth_routes_prefix: "/auth",
                  on_mount: [{ReddevsWeb.LiveUserAuth, :live_no_user}],
                  overrides: [
                    ReddevsWeb.AuthOverrides,
                    AshAuthentication.Phoenix.Overrides.Default
                  ]

    # Remove this if you do not want to use the reset password feature
    reset_route auth_routes_prefix: "/auth",
                overrides: [ReddevsWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]

    # Remove this if you do not use the confirmation strategy
    confirm_route Reddevs.Accounts.User, :confirm_new_user,
      auth_routes_prefix: "/auth",
      overrides: [ReddevsWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]

    # Remove this if you do not use the magic link strategy.
    magic_sign_in_route(Reddevs.Accounts.User, :magic_link,
      auth_routes_prefix: "/auth",
      overrides: [ReddevsWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.Default]
    )
  end

  # Other scopes may use custom stacks.
  # scope "/api", ReddevsWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:reddevs, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ReddevsWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  if Application.compile_env(:reddevs, :dev_routes) do
    import AshAdmin.Router

    scope "/admin" do
      pipe_through :browser

      ash_admin "/"
    end
  end
end
