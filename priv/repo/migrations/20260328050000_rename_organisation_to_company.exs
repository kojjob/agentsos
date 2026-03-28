defmodule AgentSos.Repo.Migrations.RenameOrganisationToCompany do
  @moduledoc """
  Renames the organisations table to companies and renames all
  organisation_id foreign key columns to company_id across the schema.
  """

  use Ecto.Migration

  def up do
    # Rename the organisations table to companies
    rename table(:organisations), to: table(:companies)

    # Rename organisation_id columns in tables that have them
    rename table(:memberships), :organisation_id, to: :company_id
    rename table(:subscriptions), :organisation_id, to: :company_id
    rename table(:usage_records), :organisation_id, to: :company_id
    rename table(:invoices), :organisation_id, to: :company_id
    rename table(:outbound_webhooks), :organisation_id, to: :company_id
    rename table(:audit_logs), :organisation_id, to: :company_id
    rename table(:app_events), :organisation_id, to: :company_id
    rename table(:search_console_data), :organisation_id, to: :company_id

    # Update the unique index on memberships
    drop_if_exists unique_index(:memberships, [:user_id, :organisation_id],
                     name: "memberships_unique_user_org_index")

    create unique_index(:memberships, [:user_id, :company_id],
             name: "memberships_unique_user_company_index")

    # Update the unique index on organisations (now companies)
    drop_if_exists unique_index(:companies, [:slug], name: "organisations_unique_slug_index")
    create unique_index(:companies, [:slug], name: "companies_unique_slug_index")
  end

  def down do
    # Reverse the unique indexes
    drop_if_exists unique_index(:companies, [:slug], name: "companies_unique_slug_index")
    create unique_index(:companies, [:slug], name: "organisations_unique_slug_index")

    drop_if_exists unique_index(:memberships, [:user_id, :company_id],
                     name: "memberships_unique_user_company_index")

    create unique_index(:memberships, [:user_id, :organisation_id],
             name: "memberships_unique_user_org_index")

    # Rename columns back
    rename table(:search_console_data), :company_id, to: :organisation_id
    rename table(:app_events), :company_id, to: :organisation_id
    rename table(:audit_logs), :company_id, to: :organisation_id
    rename table(:outbound_webhooks), :company_id, to: :organisation_id
    rename table(:invoices), :company_id, to: :organisation_id
    rename table(:usage_records), :company_id, to: :organisation_id
    rename table(:subscriptions), :company_id, to: :organisation_id
    rename table(:memberships), :company_id, to: :organisation_id

    # Rename table back
    rename table(:companies), to: table(:organisations)
  end
end
