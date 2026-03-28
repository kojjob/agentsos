defmodule AgentSosWeb.Plugs.VerifyAgentTokenTest do
  use AgentSosWeb.ConnCase, async: true

  alias AgentSos.Auth.AgentToken
  alias AgentSosWeb.Plugs.VerifyAgentToken

  describe "call/2" do
    test "assigns claims on valid JWT" do
      {:ok, token, _} = AgentToken.generate("agent-1", "run-1", "company-1")

      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer #{token}")
        |> VerifyAgentToken.call([])

      assert conn.assigns[:agent_id] == "agent-1"
      assert conn.assigns[:company_id] == "company-1"
      assert conn.assigns[:agent_claims]["jti"] == "run-1"
      refute conn.halted
    end

    test "returns 401 on missing Authorization header" do
      conn =
        build_conn()
        |> VerifyAgentToken.call([])

      assert conn.status == 401
      assert conn.halted
      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "unauthorized"
    end

    test "returns 401 on invalid token" do
      conn =
        build_conn()
        |> put_req_header("authorization", "Bearer invalid-token")
        |> VerifyAgentToken.call([])

      assert conn.status == 401
      assert conn.halted
    end

    test "returns 401 on malformed Authorization header" do
      conn =
        build_conn()
        |> put_req_header("authorization", "Basic abc123")
        |> VerifyAgentToken.call([])

      assert conn.status == 401
      assert conn.halted
    end
  end
end
