defmodule AgentSos.AccountsTest do
  use AgentSos.DataCase, async: true

  alias AgentSos.Accounts.{User, Company, CompanyMembership}
  import AgentSos.Factory

  describe "User registration" do
    test "creates user with password" do
      assert {:ok, user} =
               User
               |> Ash.Changeset.for_create(:register_with_password, %{
                 email: unique_email(),
                 password: "Password123!",
                 password_confirmation: "Password123!"
               })
               |> Ash.create()

      assert user.email
      assert user.hashed_password
    end

    test "rejects duplicate email" do
      email = unique_email()

      User
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: email,
        password: "Password123!",
        password_confirmation: "Password123!"
      })
      |> Ash.create!()

      assert {:error, _} =
               User
               |> Ash.Changeset.for_create(:register_with_password, %{
                 email: email,
                 password: "Password123!",
                 password_confirmation: "Password123!"
               })
               |> Ash.create()
    end
  end

  describe "Company" do
    test "creates org with auto-slug" do
      assert {:ok, org} =
               Company
               |> Ash.Changeset.for_create(:create, %{name: "My Cool Company"})
               |> Ash.create()

      assert org.name == "My Cool Company"
      assert org.slug == "my-cool-company"
    end

    test "slug uniqueness" do
      Company
      |> Ash.Changeset.for_create(:create, %{name: "Unique Org"})
      |> Ash.create!()

      assert {:error, _} =
               Company
               |> Ash.Changeset.for_create(:create, %{name: "Unique Org"})
               |> Ash.create()
    end
  end

  describe "CompanyMembership" do
    test "creates membership linking user and org" do
      user = create_user!()
      org = create_company!()

      assert {:ok, membership} =
               CompanyMembership
               |> Ash.Changeset.for_create(:create, %{
                 role: :member,
                 user_id: user.id,
                 company_id: org.id
               })
               |> Ash.create()

      assert membership.role == :member
    end

    test "prevents duplicate user/org membership" do
      user = create_user!()
      org = create_company!()

      create_membership!(user, org)

      assert {:error, _} =
               CompanyMembership
               |> Ash.Changeset.for_create(:create, %{
                 role: :admin,
                 user_id: user.id,
                 company_id: org.id
               })
               |> Ash.create()
    end

    test "supports role change" do
      user = create_user!()
      org = create_company!()
      membership = create_membership!(user, org, :member)

      assert {:ok, updated} =
               membership
               |> Ash.Changeset.for_update(:change_role, %{role: :admin})
               |> Ash.update()

      assert updated.role == :admin
    end
  end
end
