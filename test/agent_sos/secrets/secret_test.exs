defmodule AgentSos.Secrets.SecretTest do
  use AgentSos.DataCase, async: true
  import AgentSos.Factory

  describe "create" do
    test "creates secret with valid attributes" do
      org = create_organisation!()

      {:ok, agent} =
        AgentSos.Agents.Agent
        |> Ash.Changeset.for_create(:hire, %{
          name: "Secret Agent",
          adapter_type: :http,
          company_id: org.id
        })
        |> Ash.create()

      {:ok, secret} =
        AgentSos.Secrets.Secret
        |> Ash.Changeset.for_create(:create, %{
          name: "OPENAI_API_KEY",
          value: "sk-test-123",
          company_id: org.id,
          agent_id: agent.id
        })
        |> Ash.create()

      assert secret.name == "OPENAI_API_KEY"
      assert secret.value == "sk-test-123"
    end

    test "secret belongs to agent and company" do
      org = create_organisation!()

      {:ok, agent} =
        AgentSos.Agents.Agent
        |> Ash.Changeset.for_create(:hire, %{
          name: "Worker Agent",
          adapter_type: :claude_local,
          company_id: org.id
        })
        |> Ash.create()

      {:ok, secret} =
        AgentSos.Secrets.Secret
        |> Ash.Changeset.for_create(:create, %{
          name: "DB_PASSWORD",
          value: "super-secret",
          company_id: org.id,
          agent_id: agent.id
        })
        |> Ash.create()

      assert secret.company_id == org.id
      assert secret.agent_id == agent.id
    end
  end
end
