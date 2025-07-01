defmodule Reddevs.Repo.Migrations.CreateAshRaiseErrorFunction do
  use Ecto.Migration

  def up do
    execute """
    CREATE OR REPLACE FUNCTION ash_raise_error(error_jsonb JSONB)
    RETURNS BOOLEAN AS $$
    BEGIN
      RAISE EXCEPTION '%', (error_jsonb->>'message')::TEXT;
      RETURN FALSE;
    END;
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE OR REPLACE FUNCTION ash_raise_error(error_jsonb JSONB, pointer BIGINT)
    RETURNS BIGINT AS $$
    BEGIN
      RAISE EXCEPTION '%', (error_jsonb->>'message')::TEXT;
      RETURN NULL;
    END;
    $$ LANGUAGE plpgsql;
    """
  end

  def down do
    execute "DROP FUNCTION IF EXISTS ash_raise_error(jsonb);"
    execute "DROP FUNCTION IF EXISTS ash_raise_error(jsonb, bigint);"
  end
end
