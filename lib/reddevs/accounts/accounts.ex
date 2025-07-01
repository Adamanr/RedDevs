defmodule Reddevs.Accounts do
  use Ash.Domain, otp_app: :reddevs, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Reddevs.Accounts.Token
    resource Reddevs.Accounts.User
    resource Reddevs.Accounts.Follow
    resource Reddevs.Accounts.Notification
  end
end
