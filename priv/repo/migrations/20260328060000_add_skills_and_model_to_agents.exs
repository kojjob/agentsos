defmodule AgentSos.Repo.Migrations.AddSkillsAndModelToAgents do
  use Ecto.Migration

  def change do
    alter table(:agents) do
      add :role_title, :string
      add :skills, {:array, :string}, default: []
      add :model_provider, :string
      add :model_name, :string
      add :system_prompt, :text
      add :temperature, :float, default: 0.7
      add :max_tokens, :integer, default: 4096
      add :tools, {:array, :string}, default: []
      add :knowledge_context, :text
      add :performance_sla, :map, default: %{}
    end
  end
end
