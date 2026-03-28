defmodule AgentSos.Runs.HeartbeatRunTest do
  use AgentSos.DataCase, async: true
  import AgentSos.Factory

  defp create_agent!(org) do
    AgentSos.Agents.Agent
    |> Ash.Changeset.for_create(:hire, %{
      name: "Test Agent",
      adapter_type: :http,
      company_id: org.id
    })
    |> Ash.create!()
  end

  defp create_run!(agent, org, attrs \\ %{}) do
    default = %{
      trigger_type: :schedule,
      agent_id: agent.id,
      company_id: org.id
    }

    AgentSos.Runs.HeartbeatRun
    |> Ash.Changeset.for_create(:create, Map.merge(default, attrs))
    |> Ash.create!()
  end

  describe "create" do
    test "creates a run with valid attributes" do
      org = create_company!()
      agent = create_agent!(org)

      {:ok, run} =
        AgentSos.Runs.HeartbeatRun
        |> Ash.Changeset.for_create(:create, %{
          trigger_type: :schedule,
          agent_id: agent.id,
          company_id: org.id
        })
        |> Ash.create()

      assert run.status == :queued
      assert run.trigger_type == :schedule
      assert run.agent_id == agent.id
      assert run.company_id == org.id
    end

    test "default status is :queued" do
      org = create_company!()
      agent = create_agent!(org)
      run = create_run!(agent, org)

      assert run.status == :queued
    end
  end

  describe "start_running" do
    test "queued -> running sets started_at" do
      org = create_company!()
      agent = create_agent!(org)
      run = create_run!(agent, org)

      {:ok, running} =
        run
        |> Ash.Changeset.for_update(:start_running, %{})
        |> Ash.update()

      assert running.status == :running
      assert running.started_at != nil
    end
  end

  describe "complete" do
    test "running -> completed sets completed_at and accepts metrics" do
      org = create_company!()
      agent = create_agent!(org)
      run = create_run!(agent, org)

      {:ok, running} =
        run
        |> Ash.Changeset.for_update(:start_running, %{})
        |> Ash.update()

      {:ok, completed} =
        running
        |> Ash.Changeset.for_update(:complete, %{
          tokens_used: 1500,
          cost_cents: 25,
          duration_ms: 3200,
          stdout_log: "All tasks completed successfully."
        })
        |> Ash.update()

      assert completed.status == :completed
      assert completed.completed_at != nil
      assert completed.tokens_used == 1500
      assert completed.cost_cents == 25
      assert completed.duration_ms == 3200
      assert completed.stdout_log == "All tasks completed successfully."
    end
  end

  describe "fail" do
    test "running -> failed sets error_message" do
      org = create_company!()
      agent = create_agent!(org)
      run = create_run!(agent, org)

      {:ok, running} =
        run
        |> Ash.Changeset.for_update(:start_running, %{})
        |> Ash.update()

      {:ok, failed} =
        running
        |> Ash.Changeset.for_update(:fail, %{error_message: "Connection timeout"})
        |> Ash.update()

      assert failed.status == :failed
      assert failed.completed_at != nil
      assert failed.error_message == "Connection timeout"
    end
  end

  describe "invalid transitions" do
    test "queued -> completed should fail" do
      org = create_company!()
      agent = create_agent!(org)
      run = create_run!(agent, org)

      assert {:error, _} =
               run
               |> Ash.Changeset.for_update(:complete, %{})
               |> Ash.update()
    end

    test "queued -> failed should fail" do
      org = create_company!()
      agent = create_agent!(org)
      run = create_run!(agent, org)

      assert {:error, _} =
               run
               |> Ash.Changeset.for_update(:fail, %{error_message: "nope"})
               |> Ash.update()
    end
  end
end
