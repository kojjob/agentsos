defmodule AgentSos.Workers.HeartbeatWorkerTest do
  use AgentSos.DataCase, async: false
  use Oban.Testing, repo: AgentSos.Repo

  import AgentSos.Factory

  alias AgentSos.Workers.HeartbeatWorker
  alias AgentSos.Agents.Agent

  describe "perform/1" do
    setup do
      org = create_company!()

      {:ok, agent} =
        Agent
        |> Ash.Changeset.for_create(:hire, %{
          name: "Test Agent",
          adapter_type: :http,
          adapter_config: %{url: "https://example.com/hook"},
          monthly_budget_cents: 10_000,
          company_id: org.id
        })
        |> Ash.create()

      %{org: org, agent: agent}
    end

    test "executes full heartbeat lifecycle", %{org: org, agent: agent} do
      # Subscribe to PubSub
      Phoenix.PubSub.subscribe(AgentSos.PubSub, "companies:#{org.id}:runs")

      job_args = %{
        "agent_id" => agent.id,
        "company_id" => org.id,
        "trigger" => "manual",
        "adapter_type" => "http",
        "adapter_config" => %{"url" => "https://example.com/hook"}
      }

      assert :ok = perform_job(HeartbeatWorker, job_args)

      # Agent should be back to idle
      {:ok, updated_agent} = Ash.get(Agent, agent.id)
      assert updated_agent.status == :idle

      # Should have received PubSub broadcast
      assert_receive {:run_completed, _run_id}, 1000
    end

    test "rejects when budget exhausted", %{org: org, agent: agent} do
      # Set budget to exhausted via Ecto query
      from(a in Agent,
        where: a.id == ^agent.id,
        update: [set: [budget_used_cents: 10_000]]
      )
      |> AgentSos.Repo.update_all([])

      job_args = %{
        "agent_id" => agent.id,
        "company_id" => org.id,
        "trigger" => "manual",
        "adapter_type" => "http",
        "adapter_config" => %{"url" => "https://example.com"}
      }

      assert {:error, :budget_exhausted} = perform_job(HeartbeatWorker, job_args)
    end
  end
end
