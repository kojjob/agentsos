defmodule AgentSos.Templates.CompanyTemplateTest do
  use AgentSos.DataCase, async: true

  describe "create" do
    test "creates template with config map" do
      config = %{
        "departments" => ["Engineering", "Marketing", "Sales"],
        "hierarchy" => %{"ceo" => ["cto", "cmo"]},
        "agent_count" => 5
      }

      {:ok, template} =
        AgentSos.Templates.CompanyTemplate
        |> Ash.Changeset.for_create(:create, %{
          name: "SaaS Startup",
          description: "Template for a typical SaaS startup",
          config: config,
          is_public: true
        })
        |> Ash.create()

      assert template.name == "SaaS Startup"
      assert template.description == "Template for a typical SaaS startup"
      assert template.config == config
      assert template.is_public == true
    end

    test "defaults config to empty map and is_public to false" do
      {:ok, template} =
        AgentSos.Templates.CompanyTemplate
        |> Ash.Changeset.for_create(:create, %{
          name: "Bare Template"
        })
        |> Ash.create()

      assert template.config == %{}
      assert template.is_public == false
    end
  end
end
