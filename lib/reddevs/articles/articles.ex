defmodule Reddevs.Articles do
  use Ash.Domain, otp_app: :reddevs, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Reddevs.Articles.Article
    resource Reddevs.Articles.View
    resource Reddevs.Articles.Like
    resource Reddevs.Articles.Comment
  end
end
