shared_examples "an action that is accessible to all roles" do |action|
  let(:market)                    { create(:market) }
  let(:market2)                   { create(:market) }
  let(:organization)              { create(:organization, :buyer, markets: [market]) }
  let(:seller_organization)       { create(:organization, :seller, markets: [market]) }
  let(:admin)                     { create(:user, :admin) }
  let(:market_manager_member)     { create(:user, :market_manager, managed_markets: [market]) }
  let(:market_manager_non_member) { create(:user, :market_manager, managed_markets: [market2]) }
  let(:member)                    { create(:user, :buyer, organizations: [organization]) }
  let(:non_member)                { create(:user) }
  let(:market_seller)             { create(:user, :supplier, organizations: [seller_organization]) }

  def meet_expected_expectation
    %w(show).include?(controller.action_name) ? be_a_success : be_a_redirect
  end

  it "redirects to login given no user" do
    instance_exec(&action)

    expect(response).to redirect_to(new_user_session_path)
  end

  it "grants access to buyer only" do
    expect(member.buyer_only?).to be true

    sign_in member

    instance_exec(&action)

    expect(response).to meet_expected_expectation
  end

  it "grants access to admins" do
    sign_in admin

    instance_exec(&action)

    expect(response).to meet_expected_expectation
  end

  it "grants access to market managers" do
    sign_in market_manager_member

    instance_exec(&action)

    expect(response).to meet_expected_expectation
  end

  it "grants access to sellers" do
    sign_in market_seller

    instance_exec(&action)

    expect(response).to meet_expected_expectation
  end
end
