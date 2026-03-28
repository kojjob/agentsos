defmodule AgentSos.Accounts.SendersTest do
  use AgentSos.DataCase, async: true
  import AgentSos.Factory

  test "magic link sender handles user struct" do
    user = create_user!()
    assert :ok = AgentSos.Accounts.Senders.MagicLinkSender.send(user, "test-token", [])
  end

  test "magic link sender handles email string" do
    assert :ok = AgentSos.Accounts.Senders.MagicLinkSender.send("test@example.com", "test-token", [])
  end

  test "password reset sender handles user struct" do
    user = create_user!()
    assert :ok = AgentSos.Accounts.Senders.PasswordResetSender.send(user, "test-token", [])
  end
end
