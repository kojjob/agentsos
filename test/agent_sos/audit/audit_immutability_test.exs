defmodule AgentSos.Audit.AuditImmutabilityTest do
  use AgentSos.DataCase, async: false

  describe "audit log immutability" do
    test "can create audit log entries" do
      {:ok, log} =
        AgentSos.Audit.AuditLog
        |> Ash.Changeset.for_create(:create, %{
          action: :create,
          resource_type: "Agent",
          resource_id: Ash.UUID.generate(),
          actor_id: Ash.UUID.generate(),
          changes: %{"name" => "Test Agent"}
        })
        |> Ash.create()

      assert log.id
      assert log.action == :create
    end

    test "cannot UPDATE audit log entries (PostgreSQL trigger)" do
      {:ok, log} =
        AgentSos.Audit.AuditLog
        |> Ash.Changeset.for_create(:create, %{
          action: :create,
          resource_type: "Agent",
          resource_id: Ash.UUID.generate(),
          actor_id: Ash.UUID.generate(),
          changes: %{"name" => "Original"}
        })
        |> Ash.create()

      assert_raise Postgrex.Error, ~r/immutable/, fn ->
        {:ok, raw_id} = Ecto.UUID.dump(log.id)

        AgentSos.Repo.query!(
          "UPDATE audit_logs SET changes = $1::jsonb WHERE id = $2",
          [Jason.encode!(%{"name" => "Tampered"}), raw_id]
        )
      end
    end

    test "cannot DELETE audit log entries (PostgreSQL trigger)" do
      {:ok, log} =
        AgentSos.Audit.AuditLog
        |> Ash.Changeset.for_create(:create, %{
          action: :create,
          resource_type: "Agent",
          resource_id: Ash.UUID.generate(),
          actor_id: Ash.UUID.generate(),
          changes: %{}
        })
        |> Ash.create()

      assert_raise Postgrex.Error, ~r/immutable/, fn ->
        {:ok, raw_id} = Ecto.UUID.dump(log.id)
        AgentSos.Repo.query!("DELETE FROM audit_logs WHERE id = $1", [raw_id])
      end
    end

    test "audit log can include run_id" do
      run_id = Ash.UUID.generate()

      {:ok, log} =
        AgentSos.Audit.AuditLog
        |> Ash.Changeset.for_create(:create, %{
          action: :create,
          resource_type: "HeartbeatRun",
          resource_id: Ash.UUID.generate(),
          actor_id: Ash.UUID.generate(),
          run_id: run_id,
          changes: %{"status" => "running"}
        })
        |> Ash.create()

      assert log.run_id == run_id
    end
  end
end
