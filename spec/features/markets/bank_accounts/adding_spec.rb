require "spec_helper"

feature "Adding bank account to a market", js: true do
  let!(:admin) { create(:user, :admin) }
  let!(:market_manager) { create(:user, :market_manager) }
  let!(:market) { market_manager.managed_markets.first }
  let!(:org) { create(:organization, markets: [market]) }
  let!(:member) { create(:user, organizations: [org]) }
  let!(:non_member) { create(:user) }

  before do
    CreateBalancedCustomerForEntity.perform(market: market)
  end

  scenario "as an admin" do
    switch_to_subdomain(market.subdomain)
    sign_in_as(admin)

    visit new_admin_market_bank_account_path(market)

    fill_in "EIN", with: "20-1234567"
    fill_in "Full Legal Name", with: "John Patrick Doe"
    select "Sep", from: "representative_dob_month"
    select "17", from: "representative_dob_day"
    select "1990", from: "representative_dob_year"

    fill_in "Last 4 of SSN", with: "1234"
    fill_in "Street Address (Personal)", with: "6789 Fake Dr"
    fill_in "Zip Code (Personal)", with: "12345"

    fill_in "Name", with: "Market Bank Account"
    select("Checking", from: 'Account Type')
    fill_in "Routing Number", with: "021000021"
    fill_in "Account Number", with: "9900000002"

    click_button "Save"

    expect(page).to have_content("Successfully added a payment method")

    bank_account = Dom::BankAccount.first
    expect(bank_account.bank_name).to eq("JPMORGAN CHASE BANK")
    expect(bank_account.account_number).to eq("******0002")
    expect(bank_account.account_type).to eq("Checking")

    expect(market.reload).to be_balanced_underwritten
  end

  scenario "as a market manager" do
    switch_to_subdomain(market.subdomain)
    sign_in_as(market_manager)

    visit new_admin_market_bank_account_path(market)

    fill_in "EIN", with: "20-1234567"
    fill_in "Full Legal Name", with: "John Patrick Doe"
    select "Sep", from: "representative_dob_month"
    select "17", from: "representative_dob_day"
    select "1990", from: "representative_dob_year"

    fill_in "Last 4 of SSN", with: "1234"
    fill_in "Street Address (Personal)", with: "6789 Fake Dr"
    fill_in "Zip Code (Personal)", with: "12345"

    fill_in "Name", with: "Market Bank Account"
    select("Checking", from: 'Account Type')
    fill_in "Routing Number", with: "021000021"
    fill_in "Account Number", with: "9900000002"

    click_button "Save"

    expect(page).to have_content("Successfully added a payment method")

    bank_account = Dom::BankAccount.first
    expect(bank_account.bank_name).to eq("JPMORGAN CHASE BANK")
    expect(bank_account.account_number).to eq("******0002")
    expect(bank_account.account_type).to eq("Checking")

    expect(market.reload).to be_balanced_underwritten
  end

  scenario "as a organization member" do
    switch_to_subdomain(market.subdomain)
    sign_in_as(member)

    visit new_admin_market_bank_account_path(org)

    expect(page).to have_content("The page you were looking for doesn't exist.")
    expect(page.status_code).to eq(404)
  end

  scenario "as a non member" do
    switch_to_subdomain(market.subdomain)
    sign_in_as(non_member)

    visit new_admin_market_bank_account_path(org)

    expect(page).to have_content("The page you were looking for doesn't exist.")
    expect(page.status_code).to eq(404)
  end
end
