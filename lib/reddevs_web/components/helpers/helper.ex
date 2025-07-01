defmodule ReddevsWeb.Helpers do
  use Gettext, backend: ReddevsWeb.Gettext

  @moduledoc """
  A utility module providing helper functions for common tasks such as user session management,
  data formatting, and text processing.

  This module includes functions for:
  - Retrieving the current user from a session.
  - Formatting categories and date ranges for display.
  - Calculating the estimated reading time for a given text.

  These helpers are designed to simplify repetitive tasks and improve code readability across the application.
  """

  @doc """
  Converts Markdown to HTML.
  """
  def to_html(markdown) do
    Earmark.as_html!(markdown, %Earmark.Options{
      gfm: true,
      breaks: true
    })
  end

  def register_convert(error) do
    case error do
      "exactly 4 of email,username,accepted_code_of_conduct,accepted_terms_and_conditions must be present" ->
        "Поле должно быть заполнено!"

      "does not match" ->
        "Пароли не совпадают!"

      "is invalid" ->
        "Поле недействительно!"

      _ ->
        error
    end
  end

  def register_convert(error, key) do
    case error do
      "exactly 4 of email,username,accepted_code_of_conduct,accepted_terms_and_conditions must be present" ->
        "Поле #{key} должно быть заполнено!"

      "does not match" ->
        "Пароли не совпадают!"

      "is invalid" ->
        "Поле #{key} является недействительным"

      _ ->
        error
    end
  end

  @doc """
  Calculates the estimated reading time for a given text in minutes.

  ## Parameters
  - text: The article content as a string.
  - opts: Optional keyword list to customize calculations:
    - `:words_per_minute` - Average reading speed (default: 200).
    - `:image_time_seconds` - Additional time per image (default: 10 seconds).
    - `:code_block_time_seconds` - Additional time per code block (default: 30 seconds).
    - `:image_count` - Number of images in the content (default: 0).
    - `:code_block_count` - Number of code blocks in the content (default: 0).

  ## Returns
  - Integer representing the estimated reading time in minutes (rounded up).

  ## Examples
      iex> Reddevs.Articles.ReadingTime.calculate("This is a short article.", image_count: 1)
      1

      iex> Reddevs.Articles.ReadingTime.calculate("This article has exactly 400 words.", words_per_minute: 200)
      2
  """
  def calculate_time(text, opts \\ []) when is_binary(text) do
    words_per_minute = Keyword.get(opts, :words_per_minute, 200)
    image_time_seconds = Keyword.get(opts, :image_time_seconds, 10)
    code_block_time_seconds = Keyword.get(opts, :code_block_time_seconds, 30)
    image_count = Keyword.get(opts, :image_count, 0)
    code_block_count = Keyword.get(opts, :code_block_count, 0)

    # Count words by splitting on whitespace and filtering empty strings
    word_count =
      text
      |> String.split(~r/\s+/, trim: true)
      |> Enum.count()

    # Calculate reading time for text (in seconds)
    reading_time_seconds = word_count / words_per_minute * 60

    # Add additional time for images and code blocks
    total_time_seconds =
      reading_time_seconds + image_count * image_time_seconds +
        code_block_count * code_block_time_seconds

    # Convert to minutes and round up
    ceil(total_time_seconds / 60)
  end
end
