defmodule AgentSosWeb.Api.JsonApiTest do
  use AgentSosWeb.ConnCase, async: true

  import AgentSos.Factory

  describe "GET /api/v1/agents" do
    test "returns empty list when no agents", %{conn: conn} do
      conn = get(conn, "/api/v1/agents")
      assert json_response(conn, 200)["data"] == []
    end

    test "returns agents", %{conn: conn} do
      org = create_organisation!()

      AgentSos.Agents.Agent
      |> Ash.Changeset.for_create(:hire, %{
        name: "API Agent",
        adapter_type: :http,
        company_id: org.id
      })
      |> Ash.create!()

      conn = get(conn, "/api/v1/agents")
      data = json_response(conn, 200)["data"]
      assert length(data) == 1
      assert hd(data)["attributes"]["name"] == "API Agent"
    end
  end

  describe "POST /api/v1/agents" do
    test "creates an agent via API", %{conn: conn} do
      org = create_organisation!()

      payload = %{
        "data" => %{
          "type" => "agent",
          "attributes" => %{
            "name" => "New Agent",
            "adapter_type" => "http",
            "company_id" => org.id
          }
        }
      }

      conn =
        conn
        |> put_req_header("content-type", "application/vnd.api+json")
        |> post("/api/v1/agents", Jason.encode!(payload))

      assert json_response(conn, 201)["data"]["attributes"]["name"] == "New Agent"
    end
  end

  describe "GET /api/v1/issues" do
    test "returns empty list", %{conn: conn} do
      conn = get(conn, "/api/v1/issues")
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "GET /api/v1/runs" do
    test "returns empty list", %{conn: conn} do
      conn = get(conn, "/api/v1/runs")
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "GET /api/v1/goals" do
    test "returns empty list", %{conn: conn} do
      conn = get(conn, "/api/v1/goals")
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "GET /api/v1/projects" do
    test "returns empty list", %{conn: conn} do
      conn = get(conn, "/api/v1/projects")
      assert json_response(conn, 200)["data"] == []
    end
  end

  describe "GET /api/v1/approvals" do
    test "returns empty list", %{conn: conn} do
      conn = get(conn, "/api/v1/approvals")
      assert json_response(conn, 200)["data"] == []
    end
  end
end
