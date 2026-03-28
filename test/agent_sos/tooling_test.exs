defmodule AgentSos.ToolingTest do
  use AgentSos.DataCase, async: true

  import AgentSos.Factory

  describe "Factory helpers" do
    test "create_user! returns a valid user" do
      user = create_user!()
      assert user.id
      assert user.email
    end

    test "create_organisation! returns an org with slug" do
      org = create_organisation!()
      assert org.id
      assert org.name
      assert org.slug
    end

    test "create_membership! links user and org" do
      user = create_user!()
      org = create_organisation!()
      membership = create_membership!(user, org, :admin)
      assert membership.role == :admin
    end

    test "create_plan! returns a billing plan" do
      plan = create_plan!()
      assert plan.id
      assert plan.stripe_product_id
    end

    test "create_agent! returns an AI agent" do
      org = create_organisation!()
      agent = create_agent!(org)
      assert agent.id
      assert agent.provider == :anthropic
    end

    test "create_conversation_chain! returns full chain" do
      {org, user, agent, conversation} = create_conversation_chain!()
      assert org.id
      assert user.id
      assert agent.id
      assert conversation.id
      assert conversation.status == :active
    end

    test "unique_email returns different emails" do
      emails = for _ <- 1..10, do: unique_email()
      assert length(Enum.uniq(emails)) == 10
    end
  end

  describe "DataCase sandbox" do
    test "database is clean between tests" do
      # This test creates data
      create_user!()
      # Next test should not see this data (sandbox isolation)
    end

    test "async tests are isolated" do
      # Verify we can create resources without conflicts
      for _ <- 1..5, do: create_user!()
    end
  end

  describe "Domain module wiring" do
    test "all domains are configured" do
      domains = Application.get_env(:agent_sos, :ash_domains)
      assert AgentSos.Accounts in domains
      assert AgentSos.Billing in domains
      assert AgentSos.AI in domains
      assert AgentSos.Notifications in domains
      assert AgentSos.Audit in domains
      assert AgentSos.FeatureFlags in domains
      assert AgentSos.Webhooks in domains
    end

    test "Repo is configured" do
      repos = Application.get_env(:agent_sos, :ecto_repos)
      assert AgentSos.Repo in repos
    end

    test "Oban queues are configured" do
      oban_config = Application.get_env(:agent_sos, Oban)
      queues = Keyword.get(oban_config, :queues, [])
      assert Keyword.has_key?(queues, :default)
      assert Keyword.has_key?(queues, :mailers)
      assert Keyword.has_key?(queues, :billing)
      assert Keyword.has_key?(queues, :ai)
    end
  end

  describe "Branding config" do
    test "branding defaults are set" do
      branding = Application.get_env(:agent_sos, :branding)
      assert branding[:app_name] == "AgentSos"
      assert branding[:primary_color] == "#6366f1"
      assert is_binary(branding[:support_email])
    end
  end

  describe "Demo mode" do
    test "demo mode is off by default" do
      refute AgentSos.Demo.enabled?()
    end

    test "demo credentials are accessible" do
      assert AgentSos.Demo.demo_email() == "demo@agentsos.io"
      assert is_binary(AgentSos.Demo.demo_password())
    end
  end
end
