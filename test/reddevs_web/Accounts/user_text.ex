defmodule Reddevs.Accounts.UserTest do
  use Reddevs.DataCase
  alias Reddevs.Accounts.User
  import Ash.Changeset

  describe "authenticate_with_github" do
    test "creates new user with confirmed_at set" do
      user_info = %{
        "email" => "test@example.com",
        "name" => "Test User",
        "preferred_username" => "testuser",
        "picture" => "https://example.com/avatar.jpg",
        "profile" => "https://github.com/testuser"
      }

      changeset =
        User
        |> new()
        |> change_attribute(:user_info, user_info)
        |> change_attribute(:oauth_tokens, %{"access_token" => "token"})

      {:ok, user} = Ash.create(changeset, action: :authenticate_with_github)

      assert user.email == Ash.CiString.new("test@example.com")
      assert user.confirmed_at != nil
      assert user.username != nil
      assert user.accepted_code_of_conduct == true
      assert user.accepted_terms_and_conditions == true
      assert user.website_url == "https://github.com/testuser"
    end

    test "updates existing unconfirmed user" do
      existing_user =
        User
        |> new(%{
          email: Ash.CiString.new("test@example.com"),
          username: "existinguser",
          confirmed_at: nil,
          accepted_code_of_conduct: false,
          accepted_terms_and_conditions: false
        })
        |> Ash.create!(action: :register_with_password)

      user_info = %{
        "email" => "test@example.com",
        "name" => "Test User",
        "preferred_username" => "testuser",
        "picture" => "https://example.com/avatar.jpg",
        "profile" => "https://github.com/testuser"
      }

      changeset =
        User
        |> new()
        |> change_attribute(:user_info, user_info)
        |> change_attribute(:oauth_tokens, %{"access_token" => "token"})

      {:ok, user} = Ash.create(changeset, action: :authenticate_with_github)

      assert user.id == existing_user.id
      assert user.confirmed_at != nil
      assert user.username == "existinguser"
      assert user.accepted_code_of_conduct == true
      assert user.accepted_terms_and_conditions == true
      assert user.website_url == "https://github.com/testuser"
    end

    test "fails with invalid email" do
      user_info = %{
        "email" => "invalid",
        "name" => "Test User",
        "preferred_username" => "testuser",
        "picture" => "https://example.com/avatar.jpg"
      }

      changeset =
        User
        |> new()
        |> change_attribute(:user_info, user_info)
        |> change_attribute(:oauth_tokens, %{"access_token" => "token"})

      {:error, changeset} = Ash.create(changeset, action: :authenticate_with_github)

      assert %Ash.Error.Changes.InvalidAttribute{
               field: :email,
               message: "Invalid email format in user_info: \"invalid\""
             } in changeset.errors
    end
  end
end
