defmodule Reddevs.Accounts.Changes.NormalizeUrl do
  use Ash.Resource.Change

  def change(changeset, opts, _context) do
    field = Keyword.get(opts, :field)
    url = Ash.Changeset.get_attribute(changeset, field)

    if is_binary(url) do
      normalized_url =
        url
        |> String.trim()
        |> add_http_prefix()

      Ash.Changeset.change_attribute(changeset, field, normalized_url)
    else
      changeset
    end
  end

  defp add_http_prefix(url) do
    if url =~ ~r/^https?:\/\// do
      url
    else
      "https://" <> url
    end
  end
end
