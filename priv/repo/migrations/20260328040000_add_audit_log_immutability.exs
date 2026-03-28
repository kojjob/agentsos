defmodule AgentSos.Repo.Migrations.AddAuditLogImmutability do
  use Ecto.Migration

  def up do
    # Add run_id column
    alter table(:audit_logs) do
      add :run_id, :binary_id, null: true
    end

    # Create index for run_id lookups
    create index(:audit_logs, [:run_id])

    # Create immutability trigger — prevents UPDATE and DELETE
    execute """
    CREATE OR REPLACE FUNCTION prevent_audit_log_modification()
    RETURNS TRIGGER AS $$
    BEGIN
      RAISE EXCEPTION 'audit_logs are immutable — UPDATE and DELETE are not allowed';
    END;
    $$ LANGUAGE plpgsql;
    """

    execute """
    CREATE TRIGGER audit_log_immutability
      BEFORE UPDATE OR DELETE ON audit_logs
      FOR EACH ROW
      EXECUTE FUNCTION prevent_audit_log_modification();
    """
  end

  def down do
    execute "DROP TRIGGER IF EXISTS audit_log_immutability ON audit_logs;"
    execute "DROP FUNCTION IF EXISTS prevent_audit_log_modification();"

    alter table(:audit_logs) do
      remove :run_id
    end
  end
end
