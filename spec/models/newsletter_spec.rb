require "spec_helper"

describe Newsletter do
  describe "#recipients" do
    let!(:newsletter_type) { create :subscription_type, :newsletter }
    let!(:market) { create(:market) }
    let!(:market_manager) { create :user, :market_manager, email: "manager@santa.org", managed_markets: [market], subscription_types: [newsletter_type] }
    let!(:market_manager2) { create :user, :market_manager, email: "manager2@santa.org", managed_markets: [market]}
    let!(:newsletter) { create(:newsletter, market: market) }
    let!(:buyer_org) { create(:organization, :buyer, markets: [newsletter.market]) }
    let!(:seller_org) { create(:organization, :seller, markets: [newsletter.market]) }
    let!(:buyer) { create(:user, :buyer, email: "buyer@santa.org", organizations: [buyer_org], subscription_types: [newsletter_type] ) }
    let!(:buyer2) { create(:user, :buyer, email: "buyer2@santa.org", organizations: [buyer_org]) }
    let!(:seller) { create(:user, :supplier, email: "seller@santa.org", organizations: [seller_org], subscription_types: [newsletter_type] ) }
    let!(:seller2) { create(:user, :supplier, email: "seller2@santa.org", organizations: [seller_org]) }

    before do
      buyer2.unsubscribe_from(newsletter_type)
      seller2.unsubscribe_from(newsletter_type)
      market_manager2.unsubscribe_from(newsletter_type)
    end

    it "can include buyers" do
      newsletter.buyers = true
      recipients = newsletter.recipients.map(&:email)
      expect(recipients).to contain_exactly(buyer.email)
    end

    it "can include sellers" do
      newsletter.sellers = true
      recipients = newsletter.recipients.map(&:email)
      expect(recipients).to contain_exactly(seller.email)
    end

    it "can include market managers" do
      newsletter.market_managers = true
      recipients = newsletter.recipients.map(&:email)
      expect(recipients).to contain_exactly(market_manager.email)
    end

    it "can include all groups" do
      newsletter.buyers = true
      newsletter.sellers = true
      newsletter.market_managers = true
      recipients = newsletter.recipients.map(&:email)
      expect(recipients).to contain_exactly(market_manager.email, buyer.email, seller.email)
    end
  end
end
