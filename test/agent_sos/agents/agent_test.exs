defmodule AgentSos.Agents.AgentTest do
  use AgentSos.DataCase, async: true
  import AgentSos.Factory

  describe "hire" do
    test "creates agent with valid attributes" do
      org = create_organisation!()

      {:ok, agent} =
        AgentSos.Agents.Agent
        |> Ash.Changeset.for_create(:hire, %{
          name: "CEO Agent",
          adapter_type: :claude_local,
          company_id: org.id
        })
        |> Ash.create()

      assert agent.name == "CEO Agent"
      assert agent.adapter_type == :claude_local
      assert agent.status == :idle
      assert agent.monthly_budget_cents == 0
      assert agent.budget_used_cents == 0
    end

    test "requires name and adapter_type" do
      org = create_organisation!()

      assert {:error, _} =
               AgentSos.Agents.Agent
               |> Ash.Changeset.for_create(:hire, %{company_id: org.id})
               |> Ash.create()
    end

    test "rejects invalid adapter_type" do
      org = create_organisation!()

      assert {:error, _} =
               AgentSos.Agents.Agent
               |> Ash.Changeset.for_create(:hire, %{
                 name: "Bad Agent",
                 adapter_type: :invalid,
                 company_id: org.id
               })
               |> Ash.create()
    end
  end

  describe "status transitions" do
    setup do
      org = create_organisation!()

      {:ok, agent} =
        AgentSos.Agents.Agent
        |> Ash.Changeset.for_create(:hire, %{
          name: "Test Agent",
          adapter_type: :http,
          company_id: org.id
        })
        |> Ash.create()

      %{agent: agent, org: org}
    end

    test "idle -> running via record_heartbeat_start", %{agent: agent} do
      {:ok, updated} =
        agent
        |> Ash.Changeset.for_update(:record_heartbeat_start, %{})
        |> Ash.update()

      assert updated.status == :running
      assert updated.last_heartbeat_at != nil
    end

    test "running -> idle via record_heartbeat_complete", %{agent: agent} do
      {:ok, running} =
        agent
        |> Ash.Changeset.for_update(:record_heartbeat_start, %{})
        |> Ash.update()

      {:ok, idle} =
        running
        |> Ash.Changeset.for_update(:record_heartbeat_complete, %{})
        |> Ash.update()

      assert idle.status == :idle
    end

    test "running -> error via record_heartbeat_error", %{agent: agent} do
      {:ok, running} =
        agent
        |> Ash.Changeset.for_update(:record_heartbeat_start, %{})
        |> Ash.update()

      {:ok, errored} =
        running
        |> Ash.Changeset.for_update(:record_heartbeat_error, %{})
        |> Ash.update()

      assert errored.status == :error
    end

    test "error -> idle via recover", %{agent: agent} do
      {:ok, running} =
        agent
        |> Ash.Changeset.for_update(:record_heartbeat_start, %{})
        |> Ash.update()

      {:ok, errored} =
        running
        |> Ash.Changeset.for_update(:record_heartbeat_error, %{})
        |> Ash.update()

      {:ok, recovered} =
        errored
        |> Ash.Changeset.for_update(:recover, %{})
        |> Ash.update()

      assert recovered.status == :idle
    end

    test "cannot transition idle -> complete (invalid)", %{agent: agent} do
      assert {:error, _} =
               agent
               |> Ash.Changeset.for_update(:record_heartbeat_complete, %{})
               |> Ash.update()
    end

    test "cannot transition idle -> error (invalid)", %{agent: agent} do
      assert {:error, _} =
               agent
               |> Ash.Changeset.for_update(:record_heartbeat_error, %{})
               |> Ash.update()
    end
  end

  describe "hierarchy" do
    test "agent can have parent (reporting to)" do
      org = create_organisation!()

      {:ok, ceo} =
        AgentSos.Agents.Agent
        |> Ash.Changeset.for_create(:hire, %{
          name: "CEO",
          adapter_type: :claude_local,
          company_id: org.id
        })
        |> Ash.create()

      {:ok, cto} =
        AgentSos.Agents.Agent
        |> Ash.Changeset.for_create(:hire, %{
          name: "CTO",
          adapter_type: :claude_local,
          company_id: org.id,
          parent_agent_id: ceo.id
        })
        |> Ash.create()

      assert cto.parent_agent_id == ceo.id
    end
  end
end
