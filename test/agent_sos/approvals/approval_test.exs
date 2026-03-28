defmodule AgentSos.Approvals.ApprovalTest do
  use AgentSos.DataCase, async: true
  import AgentSos.Factory

  setup do
    org = create_company!()

    {:ok, agent} =
      AgentSos.Agents.Agent
      |> Ash.Changeset.for_create(:hire, %{
        name: "Test Agent",
        adapter_type: :http,
        company_id: org.id
      })
      |> Ash.create()

    %{org: org, agent: agent}
  end

  describe "create" do
    test "creates approval with valid attributes", %{org: org, agent: agent} do
      {:ok, approval} =
        AgentSos.Approvals.Approval
        |> Ash.Changeset.for_create(:create, %{
          type: :hire_approval,
          company_id: org.id,
          agent_id: agent.id
        })
        |> Ash.create()

      assert approval.type == :hire_approval
      assert approval.status == :pending
      assert approval.decided_at == nil
    end
  end

  describe "approve" do
    test "transitions pending to approved", %{org: org, agent: agent} do
      {:ok, approval} =
        AgentSos.Approvals.Approval
        |> Ash.Changeset.for_create(:create, %{
          type: :budget_increase,
          company_id: org.id,
          agent_id: agent.id
        })
        |> Ash.create()

      {:ok, approved} =
        approval
        |> Ash.Changeset.for_update(:approve, %{reason: "Looks good"})
        |> Ash.update()

      assert approved.status == :approved
      assert approved.reason == "Looks good"
      assert approved.decided_at != nil
    end
  end

  describe "reject" do
    test "transitions pending to rejected", %{org: org, agent: agent} do
      {:ok, approval} =
        AgentSos.Approvals.Approval
        |> Ash.Changeset.for_create(:create, %{
          type: :terminate,
          company_id: org.id,
          agent_id: agent.id
        })
        |> Ash.create()

      {:ok, rejected} =
        approval
        |> Ash.Changeset.for_update(:reject, %{reason: "Not justified"})
        |> Ash.update()

      assert rejected.status == :rejected
      assert rejected.reason == "Not justified"
      assert rejected.decided_at != nil
    end
  end

  describe "invalid transitions" do
    test "cannot approve an already approved approval", %{org: org, agent: agent} do
      {:ok, approval} =
        AgentSos.Approvals.Approval
        |> Ash.Changeset.for_create(:create, %{
          type: :hire_approval,
          company_id: org.id,
          agent_id: agent.id
        })
        |> Ash.create()

      {:ok, approved} =
        approval
        |> Ash.Changeset.for_update(:approve, %{reason: "Approved"})
        |> Ash.update()

      assert {:error, _} =
               approved
               |> Ash.Changeset.for_update(:approve, %{reason: "Double approve"})
               |> Ash.update()
    end
  end
end
