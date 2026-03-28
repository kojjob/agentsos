defmodule AgentSos.ToolingTest do
  use AgentSos.DataCase, async: true

  import AgentSos.Factory

  describe "Factory helpers" do
    test "create_user! returns a valid user" do
      user = create_user!()
      assert user.id
      assert user.email
    end

    test "create_company! returns a company with slug" do
      org = create_company!()
      assert org.id
      assert org.name
      assert org.slug
    end

    test "create_membership! links user and org" do
      user = create_user!()
      org = create_company!()
      membership = create_membership!(user, org, :admin)
      assert membership.role == :admin
    end

    test "create_plan! returns a billing plan" do
      plan = create_plan!()
      assert plan.id
      assert plan.stripe_product_id
    end

    test "unique_email returns different emails" do
      emails = for _ <- 1..10, do: unique_email()
      assert length(Enum.uniq(emails)) == 10
    end
  end

  describe "DataCase sandbox" do
    test "database is clean between tests" do
      create_user!()
    end

    test "async tests are isolated" do
      for _ <- 1..5, do: create_user!()
    end
  end

  describe "Domain module wiring" do
    test "all domains are configured" do
      domains = Application.get_env(:agent_sos, :ash_domains)
      assert AgentSos.Accounts in domains
      assert AgentSos.Billing in domains
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
      assert Keyword.has_key?(queues, :heartbeats)
    end
  end

  describe "Branding config" do
    test "branding defaults are set" do
      branding = Application.get_env(:agent_sos, :branding)
      assert branding[:app_name] == "AgentSOS"
      assert branding[:primary_color] == "#4f6ef7"
      assert is_binary(branding[:support_email])
    end
  end
end
