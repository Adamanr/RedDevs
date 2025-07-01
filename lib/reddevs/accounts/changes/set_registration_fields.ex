defmodule Reddevs.Accounts.Changes.SetRegistrationFields do
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    case changeset.action_type do
      :create ->
        changeset
        |> set_field_if_present(:username)
        |> set_field_if_present(:name)
        |> set_field_if_present(:accepted_code_of_conduct)
        |> set_field_if_present(:accepted_terms_and_conditions)

      _ ->
        changeset
    end
  end

  defp set_field_if_present(changeset, field) do
    case Ash.Changeset.get_argument(changeset, field) do
      nil -> changeset
      value -> Ash.Changeset.change_attribute(changeset, field, value)
    end
  end
end
