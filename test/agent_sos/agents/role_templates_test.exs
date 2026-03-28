defmodule AgentSos.Agents.RoleTemplatesTest do
  use ExUnit.Case, async: true

  alias AgentSos.Agents.RoleTemplates

  test "all returns 10 templates" do
    assert length(RoleTemplates.all()) == 10
  end

  test "each template has required fields" do
    for template <- RoleTemplates.all() do
      assert template.slug
      assert template.name
      assert template.model_provider
      assert template.model_name
      assert template.adapter_type
      assert is_list(template.skills)
      assert is_list(template.tools)
      assert template.suggested_budget_cents > 0
    end
  end

  test "get returns template by slug" do
    assert %{slug: "ceo"} = RoleTemplates.get("ceo")
    assert %{slug: "qa_engineer"} = RoleTemplates.get("qa_engineer")
    assert nil == RoleTemplates.get("nonexistent")
  end

  test "CEO uses opus for complex reasoning" do
    ceo = RoleTemplates.get("ceo")
    assert ceo.model_provider == :anthropic
    assert ceo.model_name == "claude-opus-4-6"
  end

  test "QA uses haiku for cost efficiency" do
    qa = RoleTemplates.get("qa_engineer")
    assert qa.model_provider == :anthropic
    assert qa.model_name == "claude-haiku-4-5"
    assert qa.suggested_budget_cents <= 10_000
  end

  test "DevOps uses cheap model" do
    devops = RoleTemplates.get("devops")
    assert devops.model_provider == :openai
    assert devops.model_name == "gpt-4o-mini"
  end
end
