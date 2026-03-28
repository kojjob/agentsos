defmodule AgentSos.Workers.BudgetMiddlewareTest do
  use AgentSos.DataCase, async: true

  import AgentSos.Factory

  alias AgentSos.Workers.BudgetMiddleware
  alias AgentSos.Agents.Agent

  describe "check_budget/1" do
    test "returns :ok when budget remaining" do
      org = create_company!()

      {:ok, agent} =
        Agent
        |> Ash.Changeset.for_create(:hire, %{
          name: "Test",
          adapter_type: :http,
          monthly_budget_cents: 1000,
          company_id: org.id
        })
        |> Ash.create()

      assert :ok = BudgetMiddleware.check_budget(agent.id)
    end

    test "returns error when budget exhausted" do
      org = create_company!()

      {:ok, agent} =
        Agent
        |> Ash.Changeset.for_create(:hire, %{
          name: "Test",
          adapter_type: :http,
          monthly_budget_cents: 100,
          company_id: org.id
        })
        |> Ash.create()

      # Exhaust budget via Ecto query on the Ash resource
      from(a in Agent,
        where: a.id == ^agent.id,
        update: [set: [budget_used_cents: 100]]
      )
      |> AgentSos.Repo.update_all([])

      assert {:error, :budget_exhausted} = BudgetMiddleware.check_budget(agent.id)
    end

    test "returns :ok when monthly budget is 0 (unlimited)" do
      org = create_company!()

      {:ok, agent} =
        Agent
        |> Ash.Changeset.for_create(:hire, %{
          name: "Test",
          adapter_type: :http,
          monthly_budget_cents: 0,
          company_id: org.id
        })
        |> Ash.create()

      assert :ok = BudgetMiddleware.check_budget(agent.id)
    end
  end

  describe "deduct_cost/2" do
    test "atomically deducts cost" do
      org = create_company!()

      {:ok, agent} =
        Agent
        |> Ash.Changeset.for_create(:hire, %{
          name: "Test",
          adapter_type: :http,
          monthly_budget_cents: 1000,
          company_id: org.id
        })
        |> Ash.create()

      assert {:ok, _new_used} = BudgetMiddleware.deduct_cost(agent.id, 50)
    end
  end
end
