require "spec_helper"

feature "A Market Manager sending a weekly Fresh Sheet" do
  let!(:user) { create(:user, :market_manager) }
  let!(:market) { user.managed_markets.first }

  before do
    switch_to_subdomain(market.subdomain)
    sign_in_as user
  end

  scenario "navigating to the page" do
    click_link "Marketing"
    click_link "Fresh Sheet"
    expect(page).to have_content("Fresh Sheet")
    expect(page).to have_css("iframe[src='#{preview_admin_fresh_sheet_path}']")
  end

  scenario "selecting a market" do
    switch_to_main_domain
    sign_in_as(create(:user, :admin))
    visit admin_fresh_sheet_path
    expect(page).to have_content("Please Select a Market")
    click_link market.name
    expect(page).to have_content("Fresh Sheet")
    expect(page).to have_css("iframe[src='#{preview_admin_fresh_sheet_path}']")
  end

  scenario "previewing" do
    visit admin_fresh_sheet_path
    expect(page).to have_content("Fresh Sheet")
    expect(page).to have_css("iframe[src='#{preview_admin_fresh_sheet_path}']")
  end

  scenario "sending a test" do
    expect(MarketMailer).to receive(:fresh_sheet).with(market, user.email).and_return(double(:mailer, deliver: true))
    visit admin_fresh_sheet_path
    click_button "Send Test"
    expect(page).to have_content("Successfully sent a test to #{user.email}")
  end

  scenario "sending to everyone" do
    expect(MarketMailer).to receive(:fresh_sheet).with(market).and_return(double(:mailer, deliver: true))
    visit admin_fresh_sheet_path
    click_button "Send Now"
    expect(page).to have_content("Successfully sent the Fresh Sheet")
  end
end
