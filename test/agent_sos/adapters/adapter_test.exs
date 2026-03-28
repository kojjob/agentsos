defmodule AgentSos.Adapters.AdapterTest do
  use ExUnit.Case, async: true

  alias AgentSos.Adapters.{AdapterContext, RunResult, Dispatcher}
  alias AgentSos.Adapters.{ClaudeLocal, ProcessAdapter, HttpAdapter, BeamNative}

  defp build_context(overrides \\ %{}) do
    %AdapterContext{
      agent_id: "agent-123",
      run_id: "run-456",
      company_id: "company-789",
      api_token: "test-token",
      config: Map.get(overrides, :config, %{}),
      system_prompt: nil,
      env_vars: %{},
      working_dir: nil
    }
  end

  describe "ClaudeLocal" do
    test "adapter_type returns :claude_local" do
      assert ClaudeLocal.adapter_type() == :claude_local
    end

    test "validate_config accepts map" do
      assert :ok = ClaudeLocal.validate_config(%{})
    end

    test "execute returns successful result in test env" do
      ctx = build_context(%{config: %{prompt: "test"}})
      assert {:ok, %RunResult{status: :completed}} = ClaudeLocal.execute(ctx)
    end
  end

  describe "ProcessAdapter" do
    test "adapter_type returns :process" do
      assert ProcessAdapter.adapter_type() == :process
    end

    test "validate_config requires command" do
      assert {:error, _} = ProcessAdapter.validate_config(%{})
      assert :ok = ProcessAdapter.validate_config(%{command: "echo"})
    end

    test "execute returns mock result in test env" do
      ctx = build_context(%{config: %{command: "echo", args: ["hello"]}})
      assert {:ok, %RunResult{status: :completed}} = ProcessAdapter.execute(ctx)
    end
  end

  describe "HttpAdapter" do
    test "adapter_type returns :http" do
      assert HttpAdapter.adapter_type() == :http
    end

    test "validate_config requires url" do
      assert {:error, _} = HttpAdapter.validate_config(%{})
      assert :ok = HttpAdapter.validate_config(%{url: "https://example.com"})
    end

    test "execute returns mock result in test env" do
      ctx = build_context(%{config: %{url: "https://example.com/webhook"}})
      assert {:ok, %RunResult{status: :completed}} = HttpAdapter.execute(ctx)
    end
  end

  describe "BeamNative" do
    test "adapter_type returns :beam_native" do
      assert BeamNative.adapter_type() == :beam_native
    end

    test "validate_config requires module and function" do
      assert {:error, _} = BeamNative.validate_config(%{})
      assert {:error, _} = BeamNative.validate_config(%{module: "Foo"})
      assert :ok = BeamNative.validate_config(%{module: "Foo", function: "run"})
    end

    test "execute returns mock result in test env" do
      ctx = build_context(%{config: %{module: "TestModule", function: "run"}})
      assert {:ok, %RunResult{status: :completed}} = BeamNative.execute(ctx)
    end
  end

  describe "Dispatcher" do
    test "dispatches to correct adapter" do
      ctx = build_context(%{config: %{prompt: "test"}})
      assert {:ok, %RunResult{}} = Dispatcher.dispatch(ctx, :claude_local)
    end

    test "returns error for unknown adapter type" do
      ctx = build_context()
      assert {:error, _} = Dispatcher.dispatch(ctx, :unknown)
    end

    test "dispatches http adapter" do
      ctx = build_context(%{config: %{url: "https://example.com"}})
      assert {:ok, %RunResult{}} = Dispatcher.dispatch(ctx, :http)
    end

    test "dispatches beam_native adapter" do
      ctx = build_context(%{config: %{module: "Test", function: "run"}})
      assert {:ok, %RunResult{}} = Dispatcher.dispatch(ctx, :beam_native)
    end

    test "dispatches process adapters for codex_local and gemini_local" do
      ctx = build_context(%{config: %{command: "echo"}})
      assert {:ok, %RunResult{}} = Dispatcher.dispatch(ctx, :codex_local)
      assert {:ok, %RunResult{}} = Dispatcher.dispatch(ctx, :gemini_local)
    end
  end
end
