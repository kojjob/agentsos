defmodule AgentSos.Agents.CostCalculatorTest do
  use ExUnit.Case, async: true

  alias AgentSos.Agents.CostCalculator

  test "pricing_for returns known pricing" do
    {inp, out} = CostCalculator.pricing_for(:anthropic, "claude-opus-4-6")
    assert inp == 15.0
    assert out == 75.0
  end

  test "pricing_for returns zero for unknown model" do
    assert {0.0, 0.0} = CostCalculator.pricing_for(:unknown, "unknown")
  end

  test "estimate_run_cost returns cents" do
    cost = CostCalculator.estimate_run_cost(:anthropic, "claude-opus-4-6", 2000, 1000)
    assert is_integer(cost)
    assert cost > 0
  end

  test "haiku is cheaper than opus" do
    opus = CostCalculator.estimate_run_cost(:anthropic, "claude-opus-4-6")
    haiku = CostCalculator.estimate_run_cost(:anthropic, "claude-haiku-4-5")
    assert haiku < opus
  end

  test "ollama is free" do
    assert 0 = CostCalculator.estimate_run_cost(:ollama, "llama-3.3-70b")
  end

  test "suggest_cheaper_alternative finds cheaper option for simple skills" do
    result = CostCalculator.suggest_cheaper_alternative(:anthropic, "claude-opus-4-6", ["testing", "qa"])
    assert {:ok, %{savings_pct: pct}} = result
    assert pct > 0
  end

  test "no cheaper alternative for already cheap model with complex skills" do
    result = CostCalculator.suggest_cheaper_alternative(:anthropic, "claude-haiku-4-5", ["strategy", "analysis"])
    # Haiku can't handle complex skills, so no cheaper capable alternative
    assert :no_cheaper_alternative = result
  end

  test "available_models groups by provider" do
    models = CostCalculator.available_models()
    assert Map.has_key?(models, :anthropic)
    assert Map.has_key?(models, :openai)
    assert length(models[:anthropic]) >= 3
  end

  test "estimate_monthly_cost multiplies by runs" do
    per_run = CostCalculator.estimate_run_cost(:anthropic, "claude-sonnet-4-6")
    monthly = CostCalculator.estimate_monthly_cost(:anthropic, "claude-sonnet-4-6", 100)
    assert monthly == per_run * 100
  end
end
