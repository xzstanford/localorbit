require "spec_helper"

feature "Verifying a bank account", js: true do
  let!(:market_manager) { create(:user, :admin, :market_manager) }
  let!(:market) { market_manager.managed_markets.first }

  context "as a market manager" do
    before do
      CreateBalancedCustomerForEntity.perform(market: market)
      switch_to_subdomain(market.subdomain)
      sign_in_as(market_manager)

      visit new_admin_market_bank_account_path(market)

      fill_in "Organization EIN", with: "20-1234567"
      fill_in "Full Legal Name", with: "John Patrick Doe"
      select "Sep", from: "representative_dob_month"
      select "17", from: "representative_dob_day"
      select "1990", from: "representative_dob_year"

      fill_in "Last 4 of SSN", with: "1234"
      fill_in "Street Address (Personal)", with: "6789 Fake Dr"
      fill_in "Zip Code (Personal)", with: "12345"

      fill_in "Name", with: "Org Bank Account"
      select("Checking", from: "Account Type")
      fill_in "Routing Number", with: "021000021"
      fill_in "Account Number", with: "9900000002"

      click_button "Save"

      expect(page).to have_content("Bank Accounts")

      click_link "Verify"
    end

    scenario "successfully verifying an account" do
      fill_in "Amount 1", with: 1
      fill_in "Amount 2", with: 1

      click_button "Verify"

      expect(page).to have_content("Bank Accounts")
      expect(Dom::BankAccount.first).to be_verfied
    end

    scenario "unsuccessfully verifying an account" do
      fill_in "Amount 1", with: 2
      fill_in "Amount 2", with: 3

      click_button "Verify"

      expect(page).to have_content("Verify Your Account")
    end
  end
end
