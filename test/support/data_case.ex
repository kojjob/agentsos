defmodule AgentSos.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias AgentSos.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import AgentSos.DataCase
    end
  end

  setup tags do
    AgentSos.DataCase.setup_sandbox(tags)
    :ok
  end

  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(AgentSos.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    pid
  end
end
