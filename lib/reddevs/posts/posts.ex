defmodule Reddevs.Posts do
  use Ash.Domain, otp_app: :reddevs, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Reddevs.Posts.Post
    resource Reddevs.Posts.Like
    resource Reddevs.Posts.View
    resource Reddevs.Posts.Comment
  end
end
