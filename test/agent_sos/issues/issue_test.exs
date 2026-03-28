defmodule AgentSos.Issues.IssueTest do
  use AgentSos.DataCase, async: true
  import AgentSos.Factory

  defp create_issue!(org, attrs \\ %{}) do
    default = %{
      title: "Fix login bug",
      company_id: org.id
    }

    AgentSos.Issues.Issue
    |> Ash.Changeset.for_create(:create, Map.merge(default, attrs))
    |> Ash.create!()
  end

  describe "create" do
    test "creates issue with valid attributes" do
      org = create_company!()

      {:ok, issue} =
        AgentSos.Issues.Issue
        |> Ash.Changeset.for_create(:create, %{
          title: "Fix login bug",
          description: "Users cannot log in",
          company_id: org.id
        })
        |> Ash.create()

      assert issue.title == "Fix login bug"
      assert issue.description == "Users cannot log in"
      assert issue.status == :open
      assert issue.priority == :medium
    end

    test "default status is :open and default priority is :medium" do
      org = create_company!()
      issue = create_issue!(org)

      assert issue.status == :open
      assert issue.priority == :medium
    end

    test "requires title" do
      org = create_company!()

      assert {:error, _} =
               AgentSos.Issues.Issue
               |> Ash.Changeset.for_create(:create, %{company_id: org.id})
               |> Ash.create()
    end
  end

  describe "transition_status" do
    setup do
      org = create_company!()
      issue = create_issue!(org)
      %{issue: issue, org: org}
    end

    test "open -> in_progress", %{issue: issue} do
      {:ok, updated} =
        issue
        |> Ash.Changeset.for_update(:transition_status, %{status: :in_progress})
        |> Ash.update()

      assert updated.status == :in_progress
    end

    test "open -> blocked", %{issue: issue} do
      {:ok, updated} =
        issue
        |> Ash.Changeset.for_update(:transition_status, %{status: :blocked})
        |> Ash.update()

      assert updated.status == :blocked
    end

    test "in_progress -> done", %{issue: issue} do
      {:ok, in_progress} =
        issue
        |> Ash.Changeset.for_update(:transition_status, %{status: :in_progress})
        |> Ash.update()

      {:ok, done} =
        in_progress
        |> Ash.Changeset.for_update(:transition_status, %{status: :done})
        |> Ash.update()

      assert done.status == :done
    end

    test "in_progress -> blocked", %{issue: issue} do
      {:ok, in_progress} =
        issue
        |> Ash.Changeset.for_update(:transition_status, %{status: :in_progress})
        |> Ash.update()

      {:ok, blocked} =
        in_progress
        |> Ash.Changeset.for_update(:transition_status, %{status: :blocked})
        |> Ash.update()

      assert blocked.status == :blocked
    end

    test "blocked -> in_progress", %{issue: issue} do
      {:ok, blocked} =
        issue
        |> Ash.Changeset.for_update(:transition_status, %{status: :blocked})
        |> Ash.update()

      {:ok, in_progress} =
        blocked
        |> Ash.Changeset.for_update(:transition_status, %{status: :in_progress})
        |> Ash.update()

      assert in_progress.status == :in_progress
    end

    test "blocked -> open", %{issue: issue} do
      {:ok, blocked} =
        issue
        |> Ash.Changeset.for_update(:transition_status, %{status: :blocked})
        |> Ash.update()

      {:ok, open} =
        blocked
        |> Ash.Changeset.for_update(:transition_status, %{status: :open})
        |> Ash.update()

      assert open.status == :open
    end

    test "done is terminal - cannot transition out", %{issue: issue} do
      {:ok, in_progress} =
        issue
        |> Ash.Changeset.for_update(:transition_status, %{status: :in_progress})
        |> Ash.update()

      {:ok, done} =
        in_progress
        |> Ash.Changeset.for_update(:transition_status, %{status: :done})
        |> Ash.update()

      assert {:error, _} =
               done
               |> Ash.Changeset.for_update(:transition_status, %{status: :in_progress})
               |> Ash.update()
    end
  end

  describe "checkout and release" do
    setup do
      org = create_company!()
      issue = create_issue!(org)
      %{issue: issue, org: org}
    end

    test "can checkout when not checked out", %{issue: issue} do
      run_id = Ash.UUID.generate()

      {:ok, checked_out} =
        issue
        |> Ash.Changeset.for_update(:checkout, %{run_id: run_id})
        |> Ash.update()

      assert checked_out.checked_out_at != nil
      assert checked_out.checked_out_by_run_id == run_id
    end

    test "cannot checkout when already checked out", %{issue: issue} do
      run_id = Ash.UUID.generate()

      {:ok, checked_out} =
        issue
        |> Ash.Changeset.for_update(:checkout, %{run_id: run_id})
        |> Ash.update()

      assert {:error, _} =
               checked_out
               |> Ash.Changeset.for_update(:checkout, %{run_id: Ash.UUID.generate()})
               |> Ash.update()
    end

    test "can release a checked out issue", %{issue: issue} do
      run_id = Ash.UUID.generate()

      {:ok, checked_out} =
        issue
        |> Ash.Changeset.for_update(:checkout, %{run_id: run_id})
        |> Ash.update()

      {:ok, released} =
        checked_out
        |> Ash.Changeset.for_update(:release, %{})
        |> Ash.update()

      assert released.checked_out_at == nil
      assert released.checked_out_by_run_id == nil
    end
  end
end
