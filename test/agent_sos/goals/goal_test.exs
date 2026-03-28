defmodule AgentSos.Goals.GoalTest do
  use AgentSos.DataCase, async: true
  import AgentSos.Factory

  describe "create" do
    test "creates goal with valid attributes" do
      org = create_organisation!()

      {:ok, goal} =
        AgentSos.Goals.Goal
        |> Ash.Changeset.for_create(:create, %{
          title: "Increase Revenue",
          description: "Grow ARR by 50%",
          company_id: org.id
        })
        |> Ash.create()

      assert goal.title == "Increase Revenue"
      assert goal.description == "Grow ARR by 50%"
      assert goal.status == :active
    end

    test "requires title" do
      org = create_organisation!()

      assert {:error, _} =
               AgentSos.Goals.Goal
               |> Ash.Changeset.for_create(:create, %{company_id: org.id})
               |> Ash.create()
    end
  end

  describe "hierarchy" do
    test "goal can have parent goal (self-referential)" do
      org = create_organisation!()

      {:ok, parent} =
        AgentSos.Goals.Goal
        |> Ash.Changeset.for_create(:create, %{
          title: "Company Vision",
          company_id: org.id
        })
        |> Ash.create()

      {:ok, child} =
        AgentSos.Goals.Goal
        |> Ash.Changeset.for_create(:create, %{
          title: "Q1 Objective",
          company_id: org.id,
          parent_goal_id: parent.id
        })
        |> Ash.create()

      assert child.parent_goal_id == parent.id
    end
  end

  describe "project linked to goal" do
    test "creates project linked to a goal" do
      org = create_organisation!()

      {:ok, goal} =
        AgentSos.Goals.Goal
        |> Ash.Changeset.for_create(:create, %{
          title: "Ship MVP",
          company_id: org.id
        })
        |> Ash.create()

      {:ok, project} =
        AgentSos.Goals.Project
        |> Ash.Changeset.for_create(:create, %{
          name: "MVP Build",
          description: "Build the first version",
          company_id: org.id,
          goal_id: goal.id
        })
        |> Ash.create()

      assert project.name == "MVP Build"
      assert project.goal_id == goal.id
      assert project.status == :planning
    end
  end
end
