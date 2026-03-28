defmodule AgentSos.Auth.AgentTokenTest do
  use ExUnit.Case, async: true

  alias AgentSos.Auth.AgentToken

  describe "generate/3" do
    test "generates a valid JWT" do
      {:ok, token, claims} = AgentToken.generate("agent-123", "run-456", "company-789")
      assert is_binary(token)
      assert claims["sub"] == "agent-123"
      assert claims["jti"] == "run-456"
      assert claims["company_id"] == "company-789"
      assert claims["iss"] == "agentsos"
      assert claims["aud"] == "agent"
    end

    test "token has 15 minute expiry" do
      {:ok, _token, claims} = AgentToken.generate("a", "r", "c")
      assert claims["exp"] - claims["iat"] == 900
    end
  end

  describe "verify_token/1" do
    test "verifies a valid token" do
      {:ok, token, _} = AgentToken.generate("agent-1", "run-1", "company-1")
      assert {:ok, claims} = AgentToken.verify_token(token)
      assert claims["sub"] == "agent-1"
    end

    test "rejects invalid token" do
      assert {:error, _} = AgentToken.verify_token("invalid-token")
    end

    test "rejects tampered token" do
      {:ok, token, _} = AgentToken.generate("agent-1", "run-1", "company-1")
      tampered = token <> "x"
      assert {:error, _} = AgentToken.verify_token(tampered)
    end
  end
end
