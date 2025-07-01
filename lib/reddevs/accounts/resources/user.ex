defmodule Reddevs.Accounts.User do
  use Ash.Resource,
    otp_app: :reddevs,
    domain: Reddevs.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAuthentication]

  require Ash.Query
  require Ash.Resource
  require Ash.Resource.Change
  require Logger

  authentication do
    add_ons do
      confirmation :confirm_new_user do
        monitor_fields [:email]
        confirm_on_create? true
        confirm_on_update? false
        require_interaction? true
        confirmed_at_field :confirmed_at

        auto_confirm_actions [
          :sign_in_with_magic_link,
          :reset_password_with_token,
          :authenticate_with_github,
          :authenticate_with_google
        ]

        sender Reddevs.Accounts.User.Senders.SendNewUserConfirmationEmail
      end
    end

    tokens do
      enabled? true
      token_resource Reddevs.Accounts.Token
      signing_secret Reddevs.Secrets
      store_all_tokens? true
      require_token_presence_for_authentication? false
    end

    session_identifier :jti

    strategies do
      password :password do
        identity_field :email
        sign_in_action_name :sign_in_with_password
      end

      magic_link do
        identity_field :email
        registration_enabled? true
        require_interaction? true
        sender Reddevs.Accounts.User.Senders.SendMagicLinkEmail
      end

      github do
        client_id Reddevs.Secrets
        redirect_uri Reddevs.Secrets
        client_secret Reddevs.Secrets
        register_action_name :authenticate_with_github
        sign_in_action_name :authenticate_with_github
        prevent_hijacking? true
      end

      google do
        client_id Reddevs.Secrets
        redirect_uri Reddevs.Secrets
        client_secret Reddevs.Secrets
        register_action_name :authenticate_with_google
        sign_in_action_name :authenticate_with_google
        prevent_hijacking? true
      end
    end
  end

  postgres do
    table "users"
    repo Reddevs.Repo
  end

  actions do
    defaults [:read]

    read :get_by_session_token do
      argument :token, :string, allow_nil?: false
      get? true

      prepare fn query, _context ->
        token_query =
          Reddevs.Accounts.Token
          |> Ash.Query.for_read(:get_token, %{token: arg(:token), purpose: "user"})
          |> Ash.read_one()

        case token_query do
          {:ok, token} when not is_nil(token) ->
            query
            |> Ash.Query.filter(id == ^token.user_id)

          _ ->
            query
            |> Ash.Query.filter(false)
        end
      end
    end

    read :get_by_subject do
      description "Get a user by the subject claim in a JWT"
      argument :subject, :string, allow_nil?: false
      get? true
      prepare AshAuthentication.Preparations.FilterBySubject
    end

    read :get_by_username do
      description "Looks up a user by their username"
      get? true

      argument :username, :string do
        allow_nil? false
      end

      filter expr(username == ^arg(:username))
    end

    read :get_by_email do
      description "Looks up a user by their email"
      get? true

      argument :email, :ci_string do
        allow_nil? false
      end

      filter expr(email == ^arg(:email))
    end

    read :sign_in_with_password do
      description "Attempt to sign in using a email and password."
      get? true

      argument :email, :ci_string do
        description "The email to use for retrieving the user."
        allow_nil? false
      end

      argument :password, :string do
        description "The password to check for the matching user."
        allow_nil? false
        sensitive? true
      end

      prepare AshAuthentication.Strategy.Password.SignInPreparation

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
    end

    read :sign_in_with_token do
      description "Attempt to sign in using a short-lived sign in token."
      get? true

      argument :token, :string do
        description "The short-lived sign in token."
        allow_nil? false
        sensitive? true
      end

      prepare AshAuthentication.Strategy.Password.SignInWithTokenPreparation

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
    end

    update :update_profile do
      description "Update user profile information"
      require_atomic? false

      accept [
        :name,
        :email,
        :username,
        :pronouns,
        :bio,
        :website_url,
        :location,
        :employer_name,
        :employer_url,
        :currently_learning,
        :available_for,
        :profile_image,
        :cover_image,
        :preferred_language,
        :theme,
        :config
      ]

      change {Reddevs.Accounts.Changes.NormalizeUrl, field: :profile_image}
      change {Reddevs.Accounts.Changes.NormalizeUrl, field: :cover_image}
      change {Reddevs.Accounts.Changes.NormalizeUrl, field: :website_url}
      change {Reddevs.Accounts.Changes.NormalizeUrl, field: :employer_url}
    end

    update :update_password do
      description "Update user password"
      accept []
      argument :current_password, :string, allow_nil?: false, sensitive?: true
      argument :password, :string, allow_nil?: false, sensitive?: true
      argument :password_confirmation, :string, allow_nil?: false, sensitive?: true
      validate confirm(:password, :password_confirmation)

      validate {AshAuthentication.Strategy.Password.PasswordValidation,
                strategy_name: :password, password_argument: :current_password}

      change {AshAuthentication.Strategy.Password.HashPasswordChange, strategy_name: :password}
    end

    update :update_email do
      description "Update user email address"
      accept [:email]
      argument :current_password, :string, allow_nil?: false, sensitive?: true

      validate {AshAuthentication.Strategy.Password.PasswordValidation,
                strategy_name: :password, password_argument: :current_password}
    end

    update :update_privacy_settings do
      description "Update user privacy settings"
      accept [:config]
      require_atomic? false

      change fn changeset, _context ->
        config = Ash.Changeset.get_argument(changeset, :config) || %{}
        Ash.Changeset.change_attribute(changeset, :config, config)
      end
    end

    update :change_password do
      require_atomic? false
      accept []
      argument :current_password, :string, sensitive?: true, allow_nil?: false

      argument :password, :string,
        sensitive?: true,
        allow_nil?: false,
        constraints: [min_length: 8]

      argument :password_confirmation, :string, sensitive?: true, allow_nil?: false
      validate confirm(:password, :password_confirmation)

      validate {AshAuthentication.Strategy.Password.PasswordValidation,
                strategy_name: :password, password_argument: :current_password}

      change {AshAuthentication.Strategy.Password.HashPasswordChange, strategy_name: :password}
    end

    update :reset_password_with_token do
      argument :reset_token, :string do
        allow_nil? false
        sensitive? true
      end

      argument :password, :string do
        description "The proposed password for the user, in plain text."
        allow_nil? false
        constraints min_length: 8
        sensitive? true
      end

      argument :password_confirmation, :string do
        description "The proposed password for the user (again), in plain text."
        allow_nil? false
        sensitive? true
      end

      validate AshAuthentication.Strategy.Password.ResetTokenValidation
      validate AshAuthentication.Strategy.Password.PasswordConfirmationValidation
      change AshAuthentication.Strategy.Password.HashPasswordChange
      change AshAuthentication.GenerateTokenChange
    end

    create :register_with_password do
      description "Register a new user with a email and password."

      accept [
        :email,
        :username,
        :accepted_code_of_conduct,
        :accepted_terms_and_conditions
      ]

      argument :username, :string do
        allow_nil? false
        constraints min_length: 3, max_length: 30
      end

      argument :password, :string do
        description "The proposed password for the user, in plain text."
        allow_nil? false
        constraints min_length: 8
        sensitive? true
      end

      argument :password_confirmation, :string do
        description "The proposed password for the user (again), in plain text."
        allow_nil? false
        sensitive? true
      end

      validate AshAuthentication.Strategy.Password.PasswordConfirmationValidation

      validate present([
                 :email,
                 :username,
                 :accepted_code_of_conduct,
                 :accepted_terms_and_conditions
               ])

      change fn changeset, _context ->
        username = Ash.Changeset.get_argument(changeset, :username)

        changeset
        |> Ash.Changeset.change_attribute(:name, username)
        |> Ash.Changeset.change_attribute(:username, username)
      end

      change fn changeset, _context ->
        Ash.Changeset.change_attribute(changeset, :last_seen_at, DateTime.utc_now())
      end

      change AshAuthentication.Strategy.Password.HashPasswordChange
      change AshAuthentication.GenerateTokenChange

      change fn changeset, _context ->
        config = %{
          newsletter: true,
          email_digest: :weekly,
          email_comments: true,
          email_mentions: true,
          email_badge: true,
          email_follower: true
        }

        Ash.Changeset.change_attribute(changeset, :config, config)
      end

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
    end

    create :sign_in_with_magic_link do
      description "Sign in or register a user with magic link."

      argument :token, :string do
        description "The token from the magic link that was sent to the user"
        allow_nil? false
      end

      argument :username, :string do
        description "Username (required for new users)"
        allow_nil? true
      end

      argument :name, :string do
        allow_nil? true
      end

      argument :accepted_code_of_conduct, :boolean do
        allow_nil? true
        default false
      end

      argument :accepted_terms_and_conditions, :boolean do
        allow_nil? true
        default false
      end

      upsert? true
      upsert_identity :unique_email
      upsert_fields [:email]
      change AshAuthentication.Strategy.MagicLink.SignInChange
      change {Reddevs.Accounts.Changes.SetRegistrationFields, []}

      metadata :token, :string do
        allow_nil? false
      end
    end

    create :authenticate_with_github do
      description "Sign in or register a user with GitHub OAuth"
      argument :user_info, :map, allow_nil?: false
      argument :oauth_tokens, :map, allow_nil?: false
      upsert? true
      upsert_identity :unique_email

      upsert_fields [
        :email,
        :username,
        :bio,
        :location,
        :website_url,
        :employer_name,
        :profile_image,
        :last_seen_at,
        :accepted_code_of_conduct,
        :accepted_terms_and_conditions,
        :config,
        :confirmed_at
      ]

      validate fn changeset, _context ->
        user_info = Ash.Changeset.get_argument(changeset, :user_info)
        email = Map.get(user_info, "email")

        if is_binary(email) && String.match?(email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/) do
          :ok
        else
          {:error, "Invalid email format in user_info: #{inspect(email)}"}
        end
      end

      change fn changeset, _context ->
        user_info = Ash.Changeset.get_argument(changeset, :user_info)
        Logger.debug("GitHub authentication for user_info: #{inspect(user_info)}")

        email = Map.get(user_info, "email")
        github_name = Map.get(user_info, "name")
        login = Map.get(user_info, "preferred_username")

        if is_nil(email) do
          Ash.Changeset.add_error(
            changeset,
            Ash.Error.Changes.InvalidAttribute.exception(
              field: :email,
              message: "No email provided in user_info: #{inspect(user_info)}"
            )
          )
        else
          profile_image =
            Map.get(user_info, "picture") ||
              "https://i.pinimg.com/736x/97/29/31/972931f5f61451c5b0bed5f3a0520ec5.jpg"

          changeset =
            changeset
            |> Ash.Changeset.change_attribute(:email, Ash.CiString.new(email))
            |> Ash.Changeset.change_attribute(:last_seen_at, DateTime.utc_now())
            |> Ash.Changeset.change_attribute(:confirmed_at, DateTime.utc_now())

          existing_user =
            case Ash.get(Reddevs.Accounts.User, %{email: email}, action: :get_by_email) do
              {:ok, user} when not is_nil(user) ->
                Logger.debug(
                  "Existing user found: #{inspect(user.id)}, confirmed_at: #{inspect(user.confirmed_at)}"
                )

                user

              _ ->
                Logger.debug("No existing user found for email: #{email}")
                nil
            end

          changeset =
            if existing_user && existing_user.id do
              Logger.debug("Updating existing user: #{existing_user.id}")

              changeset
              |> Ash.Changeset.change_attribute(:username, existing_user.username || login)
              |> Ash.Changeset.change_attribute(
                :website_url,
                Map.get(user_info, "profile") || existing_user.website_url
              )
              |> Ash.Changeset.change_attribute(:profile_image, profile_image)
            else
              Logger.debug("Creating new user for email: #{email}")
              username = login

              default_config = %{
                newsletter: true,
                email_digest: :weekly,
                email_comments: true,
                email_mentions: true,
                email_badge: true,
                email_follower: true
              }

              changeset
              |> Ash.Changeset.change_attribute(:username, username)
              |> Ash.Changeset.change_attribute(:name, github_name || username)
              |> Ash.Changeset.change_attribute(:bio, Map.get(user_info, "bio"))
              |> Ash.Changeset.change_attribute(:location, Map.get(user_info, "location"))
              |> Ash.Changeset.change_attribute(:website_url, Map.get(user_info, "profile"))
              |> Ash.Changeset.change_attribute(:employer_name, Map.get(user_info, "company"))
              |> Ash.Changeset.change_attribute(:profile_image, profile_image)
              |> Ash.Changeset.change_attribute(:accepted_code_of_conduct, true)
              |> Ash.Changeset.change_attribute(:accepted_terms_and_conditions, true)
              |> Ash.Changeset.change_attribute(:config, default_config)
            end

          changeset
        end
      end

      change AshAuthentication.GenerateTokenChange

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
    end

    create :authenticate_with_google do
      description "Sign in or register a user with Google OAuth"
      argument :user_info, :map, allow_nil?: false
      argument :oauth_tokens, :map, allow_nil?: false
      upsert? true
      upsert_identity :unique_email

      upsert_fields [
        :email,
        :username,
        :bio,
        :location,
        :website_url,
        :employer_name,
        :profile_image,
        :last_seen_at,
        :accepted_code_of_conduct,
        :accepted_terms_and_conditions,
        :config,
        :confirmed_at
      ]

      validate fn changeset, _context ->
        user_info = Ash.Changeset.get_argument(changeset, :user_info)
        email = Map.get(user_info, "email")

        if is_binary(email) && String.match?(email, ~r/^[^\s@]+@[^\s@]+\.[^\s@]+$/) do
          :ok
        else
          {:error, "Invalid email format in user_info: #{inspect(email)}"}
        end
      end

      change fn changeset, _context ->
        user_info = Ash.Changeset.get_argument(changeset, :user_info)
        Logger.debug("Google authentication for user_info: #{inspect(user_info)}")

        email = Map.get(user_info, "email")
        google_name = Map.get(user_info, "name")

        login =
          Map.get(user_info, "preferred_username") ||
            Map.get(user_info, "email") |> String.split("@") |> List.first()

        if is_nil(email) do
          Ash.Changeset.add_error(
            changeset,
            Ash.Error.Changes.InvalidAttribute.exception(
              field: :email,
              message: "No email provided in user_info: #{inspect(user_info)}"
            )
          )
        else
          raw_picture = Map.get(user_info, "picture")

          profile_image =
            if raw_picture && String.contains?(raw_picture, "lh3.googleusercontent.com") do
              String.replace(raw_picture, ~r/s\d+-c$/, "s256-c")
            else
              "https://i.pinimg.com/736x/97/29/31/972931f5f61451c5b0bed5f3a0520ec5.jpg"
            end

          changeset =
            changeset
            |> Ash.Changeset.change_attribute(:email, Ash.CiString.new(email))
            |> Ash.Changeset.change_attribute(:last_seen_at, DateTime.utc_now())
            |> Ash.Changeset.change_attribute(:confirmed_at, DateTime.utc_now())

          existing_user =
            case Ash.get(Reddevs.Accounts.User, %{email: email}, action: :get_by_email) do
              {:ok, user} when not is_nil(user) ->
                Logger.debug(
                  "Existing user found: #{inspect(user.id)}, confirmed_at: #{inspect(user.confirmed_at)}"
                )

                user

              _ ->
                Logger.debug("No existing user found for email: #{email}")
                nil
            end

          changeset =
            if existing_user && existing_user.id do
              Logger.debug("Updating existing user: #{existing_user.id}")

              changeset
              |> Ash.Changeset.change_attribute(:username, existing_user.username || login)
              |> Ash.Changeset.change_attribute(:profile_image, profile_image)
            else
              Logger.debug("Creating new user for email: #{email}")
              username = login

              default_config = %{
                newsletter: true,
                email_digest: :weekly,
                email_comments: true,
                email_mentions: true,
                email_badge: true,
                email_follower: true
              }

              changeset
              |> Ash.Changeset.change_attribute(:username, username)
              |> Ash.Changeset.change_attribute(:name, google_name || username)
              |> Ash.Changeset.change_attribute(:profile_image, profile_image)
              |> Ash.Changeset.change_attribute(:accepted_code_of_conduct, true)
              |> Ash.Changeset.change_attribute(:accepted_terms_and_conditions, true)
              |> Ash.Changeset.change_attribute(:config, default_config)
            end

          changeset
        end
      end

      change AshAuthentication.GenerateTokenChange

      metadata :token, :string do
        description "A JWT that can be used to authenticate the user."
        allow_nil? false
      end
    end

    action :request_password_reset_token do
      description "Send password reset instructions to a user if they exist."

      argument :email, :ci_string do
        allow_nil? false
      end

      run {AshAuthentication.Strategy.Password.RequestPasswordReset, action: :get_by_email}
    end

    action :request_magic_link do
      argument :email, :ci_string do
        allow_nil? false
      end

      run AshAuthentication.Strategy.MagicLink.Request
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    policy action_type(:read) do
      authorize_if always()
    end

    policy action([:create, :update, :destroy]) do
      authorize_if expr(author_id == ^actor(:id))
    end

    policy action([:increment_views, :like, :unlike]) do
      authorize_if always()
    end

    policy action(:sign_in_with_password) do
      authorize_if always()
    end

    policy action(:sign_in_with_token) do
      authorize_if always()
    end

    policy action(:register_with_password) do
      authorize_if always()
    end

    policy action(:request_password_reset_token) do
      authorize_if always()
    end

    policy action(:reset_password_with_token) do
      authorize_if always()
    end

    policy action(:sign_in_with_magic_link) do
      authorize_if always()
    end

    policy action(:request_magic_link) do
      authorize_if always()
    end

    policy action(:get_by_username) do
      authorize_if always()
    end

    policy action(:get_by_email) do
      authorize_if always()
    end

    policy action(:update_profile) do
      authorize_if expr(id == ^actor(:id))
    end

    policy action(:update_password) do
      authorize_if expr(id == ^actor(:id))
    end

    policy action(:update_email) do
      authorize_if expr(id == ^actor(:id))
    end

    policy action(:update_privacy_settings) do
      authorize_if expr(id == ^actor(:id))
    end

    policy action(:change_password) do
      authorize_if expr(id == ^actor(:id))
    end

    policy action_type(:read) do
      authorize_if always()
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :ci_string do
      allow_nil? false
      public? true
    end

    attribute :hashed_password, :string do
      allow_nil? true
      sensitive? true
    end

    attribute :username, :string do
      constraints min_length: 3, max_length: 30
      allow_nil? false
    end

    attribute :name, :string
    attribute :pronouns, :string, default: "robot"

    attribute :bio, :string do
      constraints max_length: 350
    end

    attribute :website_url, :string
    attribute :location, :string
    attribute :employer_name, :string
    attribute :employer_url, :string
    attribute :currently_learning, {:array, :string}
    attribute :available_for, :string

    attribute :profile_image, :string,
      default: "https://i.pinimg.com/736x/97/29/31/972931f5f61451c5b0bed5f3a0520ec5.jpg"

    attribute :cover_image, :string,
      default: "https://i.pinimg.com/736x/a4/a5/3d/a4a53d08b410f3f4949f5ceada6c7492.jpg"

    attribute :links, :map
    attribute :preferred_language, :string, default: "en"
    attribute :theme, :string, default: "light"
    attribute :config, :map
    attribute :moderation_notes, :string
    attribute :trust_level, :integer, default: 0
    attribute :article_count, :integer, default: 0
    attribute :comment_count, :integer, default: 0
    attribute :reputation, :integer, default: 0
    attribute :badges, {:array, :string}, default: []
    attribute :last_seen_at, :utc_datetime_usec
    attribute :accepted_code_of_conduct, :boolean, default: false
    attribute :accepted_terms_and_conditions, :boolean, default: false
    attribute :confirmed_at, :utc_datetime_usec
  end

  relationships do
    has_many :posts, Reddevs.Posts.Post do
      destination_attribute :author_id
    end

    has_many :notifications, Reddevs.Accounts.Notification do
      destination_attribute :user_id
    end

    has_many :tokens, Reddevs.Accounts.Token do
      destination_attribute :user_id
    end

    many_to_many :followers, Reddevs.Accounts.User do
      through Reddevs.Accounts.Follow
      source_attribute :id
      source_attribute_on_join_resource :followed_id
      destination_attribute :id
      destination_attribute_on_join_resource :follower_id
    end

    many_to_many :following, Reddevs.Accounts.User do
      through Reddevs.Accounts.Follow
      source_attribute :id
      source_attribute_on_join_resource :follower_id
      destination_attribute :id
      destination_attribute_on_join_resource :followed_id
    end
  end

  identities do
    identity :unique_email, [:email]
    identity :unique_username, [:username]
  end
end
