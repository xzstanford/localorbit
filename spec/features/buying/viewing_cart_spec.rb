require "spec_helper"

describe "Viewing the cart", :js do
  before(:each) do
    Timecop.travel("May 12, 2014")
  end

  let!(:user)             { create(:user, :buyer) }
  let!(:buyer)            { create(:organization, :single_location, :buyer, users: [user]) }

  let!(:fulton_farms)     { create(:organization, :seller, :single_location, name: "Fulton St. Farms") }
  let!(:ada_farms)        { create(:organization, :seller, :single_location, name: "Ada Farms") }

  let(:market)            { create(:market, :with_addresses, organizations: [buyer, fulton_farms, ada_farms]) }
  let(:delivery_schedule) { create(:delivery_schedule, :percent_fee,  market: market, day: 5, fee_label: "Service Fee", order_minimum: 10) }
  let(:delivery_day) { DateTime.parse("May 16, 2014, 11:00:00") }
  let(:delivery) do
    create(:delivery,
           delivery_schedule: delivery_schedule,
           deliver_on: delivery_day,
           cutoff_time: delivery_day - delivery_schedule.order_cutoff.hours
    )
  end

  # Fulton St. Farms
  let!(:bananas) { create(:product, name: "Bananas", organization: fulton_farms, delivery_schedules: [delivery_schedule]) }
  let!(:bananas_lot) { create(:lot, product: bananas, quantity: 100) }
  let!(:bananas_price_buyer_base) do
    create(:price, :past_price, market: market, product: bananas, min_quantity: 1, organization: buyer, sale_price: 0.50)
  end

  let!(:kale) { create(:product, :sellable, name: "Kale", organization: fulton_farms, delivery_schedules: [delivery_schedule]) }
  let!(:kale_lot) { kale.lots.first.update_attribute(:quantity, 100) }
  let!(:kale_lot_expired) { create(:lot, product: kale, number: 1, quantity: 25, expires_at: DateTime.parse("May 15, 2014")) }
  let!(:kale_price_tier1) do
    create(:price, :past_price, market: market, product: kale, min_quantity: 4, sale_price: 2.50)
  end

  let!(:kale_price_tier2) do
    create(:price, :past_price, market: market, product: kale, min_quantity: 6, sale_price: 1.00)
  end

  # Ada Farms
  let!(:potatoes) { create(:product, :sellable, name: "Potatoes", organization: ada_farms, delivery_schedules: [delivery_schedule]) }
  let!(:potatoes_lot) { create(:lot, product: potatoes, quantity: 100) }

  let!(:beans) { create(:product, :sellable, name: "Beans", organization: ada_farms, delivery_schedules: [delivery_schedule]) }
  let!(:carrots) { create(:product, :sellable, name: "Carrots", organization: ada_farms, delivery_schedules: [delivery_schedule]) }

  let!(:cart) { create(:cart, market: market, organization: buyer, user: user, location: buyer.locations.first, delivery: delivery) }
  let!(:cart_bananas) { create(:cart_item, cart: cart, product: bananas, quantity: 10) }
  let!(:cart_potatoes) { create(:cart_item, cart: cart, product: potatoes, quantity: 5) }
  let!(:cart_kale) { create(:cart_item, cart: cart, product: kale, quantity: 20) }
  let!(:cart_carrots) { create(:cart_item, cart: cart, product: carrots, quantity: 1) }

  after(:each) do
    Timecop.return
  end

  def bananas_item
    Dom::Cart::Item.find_by_name(/\ABananas/)
  end

  def carrots_item
    Dom::Cart::Item.find_by_name(/\ACarrots/)
  end

  def cart_link
    Dom::CartLink.first
  end

  def cart_totals
    Dom::Cart::Totals.first
  end

  def kale_item
    Dom::Cart::Item.find_by_name(/\AKale/)
  end

  def potatoes_item
    Dom::Cart::Item.find_by_name(/\APotatoes/)
  end

  before do
    switch_to_subdomain(market.subdomain)
    sign_in_as(user)

    cart_link.node.click
    expect(page).to have_content("Your Order")
  end

  it "allows buyer to add note" do
    expect(page).to have_content("Note")
  end

  it "uses correct delivery fee label" do
    expect(page).to have_content(delivery_schedule.fee_label)
  end

  it "lists products grouped by organization" do
    fulton_farms_group = Dom::Cart::SellerGroup.find_by_seller("Fulton St. Farms")
    ada_farms_group = Dom::Cart::SellerGroup.find_by_seller("Ada Farms")

    expect(page).to have_content("Bananas")
    expect(page).to have_content("Kale")
    expect(page).to have_content("Potatoes")
  end

  it "shows an error when minimum is not met" do
    bananas_item.set_quantity(0)
    expect(page).to_not have_content("Bananas")

    potatoes_item.set_quantity(0)
    expect(page).to_not have_content("Potatoes")

    kale_item.set_quantity(0)
    expect(page).to_not have_content("Kale")

    expect(page).to have_content("Your order does not meet the subtotal order minimum")
    carrots_item.set_quantity(4)
    carrots_item.quantity_field.click
    expect(page).to_not have_content("Your order does not meet the subtotal order minimum")
  end

  context "scoped to users" do
    let!(:other_user)      { create(:user, :buyer, organizations: [buyer]) }
    let!(:other_cart)      { create(:cart, market: market, organization: buyer, user: other_user, location: buyer.locations.first, delivery: delivery) }
    let!(:other_cart_kale) { create(:cart_item, cart: other_cart, product: kale, quantity: 6) }

    it "shows the cart for the current user" do
      expect(bananas_item.quantity_field.value).to eql("10")
      expect(kale_item.quantity_field.value).to eql("20")
      expect(potatoes_item.quantity_field.value).to eql("5")

      sign_out
      sign_in_as(other_user)

      cart_link.node.click
      expect(page).to have_content("Your Order")
      expect(kale_item.quantity_field.value).to eql("6")
    end
  end

  context "delivery information" do
    context "for dropoff" do
      let(:address) { buyer.locations.first }

      it "shows delivery address" do
        within("#address") do
          expect(page).to have_content("Delivery Address")
          expect(page).to have_content("Delivery on Friday May 16, 2014 between 7:00AM and 11:00AM")
          expect(page).to have_content(address.address)
          expect(page).to have_content(address.city)
          expect(page).to have_content(address.state)
          expect(page).to have_content(address.zip)
        end
      end
    end

    context "for pickup" do
      let!(:delivery_schedule) { create(:delivery_schedule, :buyer_pickup,  market: market, day: 5) }
      let(:address) { market.addresses.first }

      it "shows pickup address" do
        within("#address") do
          expect(page).to have_content("Delivery Address")
          expect(page).to have_content("Pickup on Friday May 16, 2014 between 10:00AM and 12:00PM")
          expect(page).to have_content(address.address)
          expect(page).to have_content(address.city)
          expect(page).to have_content(address.state)
          expect(page).to have_content(address.zip)
        end
      end
    end
  end

  context "delivery fees" do
    it "show in the totals" do
      expect(cart_totals.delivery_fees).to have_content("$10.75")

      kale_item.set_quantity(98)
      bananas_item.quantity_field.click
      expect(Dom::CartLink.first).to have_content("Item updated!")
      expect(Dom::CartLink.first).to_not have_content("Item updated!")

      expect(cart_totals.delivery_fees).to have_content("$30.25")
    end

    context "when there are no delivery fees" do
      let!(:delivery_schedule) { create(:delivery_schedule, :fixed_fee, fee: 0, market: market, day: 5) }

      it "displays as 'Free!'" do
        expect(cart_totals.delivery_fees).to have_content("Free!")

        kale_item.set_quantity(98)
        bananas_item.quantity_field.click
        expect(Dom::CartLink.first).to have_content("Item updated!")
        expect(Dom::CartLink.first).to_not have_content("Item updated!")

        expect(cart_totals.delivery_fees).to have_content("Free!")
      end
    end
  end

  context "total" do
    it "is the subtotal plus delivery fees" do
      expect(cart_totals.total).to have_content("$53.75")

      kale_item.set_quantity(98)
      bananas_item.quantity_field.click
      expect(Dom::CartLink.first).to have_content("Item updated!")
      expect(Dom::CartLink.first).to_not have_content("Item updated!")

      expect(cart_totals.total).to have_content("$151.25")
    end
  end

  context "updating quantity" do
    it "updates the per-unit price based on the pricing tier it fits in" do
      expect(kale_item.price_for_quantity).to have_content("$1.00")

      kale_item.set_quantity(4)
      bananas_item.quantity_field.click
      expect(Dom::CartLink.first).to have_content("Item updated!")
      expect(Dom::CartLink.first).to_not have_content("Item updated!")
      expect(kale_item.price_for_quantity).to have_content("$2.50")

      kale_item.set_quantity(1)
      bananas_item.quantity_field.click
      expect(Dom::CartLink.first).to have_content("Item updated!")
      expect(Dom::CartLink.first).to_not have_content("Item updated!")
      expect(kale_item.price_for_quantity).to have_content("$3.00")

      kale_item.set_quantity(5)
      bananas_item.quantity_field.click
      expect(Dom::CartLink.first).to have_content("Item updated!")
      expect(Dom::CartLink.first).to_not have_content("Item updated!")
      expect(kale_item.price_for_quantity).to have_content("$2.50")
    end

    it "updates the overall price" do
      expect(kale_item.price).to have_content("$20.00")

      kale_item.set_quantity(4)
      bananas_item.quantity_field.click
      expect(Dom::CartLink.first).to have_content("Item updated!")
      expect(Dom::CartLink.first).to_not have_content("Item updated!")
      expect(kale_item.price).to have_content("$10.00")

      kale_item.set_quantity(5)
      bananas_item.quantity_field.click
      expect(Dom::CartLink.first).to have_content("Item updated!")
      expect(Dom::CartLink.first).to_not have_content("Item updated!")
      expect(kale_item.price).to have_content("$12.50")

      kale_item.set_quantity(1)
      bananas_item.quantity_field.click
      expect(Dom::CartLink.first).to have_content("Item updated!")
      expect(Dom::CartLink.first).to_not have_content("Item updated!")
      expect(kale_item.price).to have_content("$3.00")
    end

    it "updates item subtotal" do
      expect(cart_totals.subtotal).to have_content("$43.00")

      kale_item.set_quantity(98)
      bananas_item.quantity_field.click
      expect(Dom::CartLink.first).to have_content("Item updated!")
      expect(Dom::CartLink.first).to_not have_content("Item updated!")

      expect(cart_totals.subtotal).to have_content("$121.00")
    end

    context "when updated quantity is greater than available products" do
      before do
        kale_item.set_quantity(101)
        bananas_item.quantity_field.click
        expect(Dom::CartLink.first).to have_content("Item updated!")
        expect(Dom::CartLink.first).to_not have_content("Item updated!")
        expect(page).to have_content("Quantity of Kale (boxes) available for purchase: 100")
      end

      it "resets the quantity to the entire available quantity" do
        expect(kale_item.quantity_field.value).to eql("100")
      end
    end

    context "when entering an invalid quantity" do
      before do
        kale_item.set_quantity("bad")
        bananas_item.quantity_field.click
      end

      it "marks the quantity field as being an error" do
        expect(kale_item.node).to have_css(".field_with_errors")
      end

      it "displays an error messages" do
        expect(page).to have_content("Quantity is not a number")
      end
    end

    context "when entering a negative quantity" do
      before do
        kale_item.set_quantity(-3)
        bananas_item.quantity_field.click
      end

      it "marks the quantity field as being an error" do
        expect(kale_item.node).to have_css(".field_with_errors")
      end

      it "displays an error messages" do
        expect(page).to have_content("Quantity must be greater than or equal to 0")
      end
    end
  end

  context "place order button" do
    it "enables the button when purchase order payment method chosen" do
      expect(page.find('#place-order-button')[:disabled]).to be

      choose "Pay by Purchase Order"

      expect(page.find('#place-order-button')[:disabled]).to be_falsey
    end

    context "credit cards" do
      xit "stays disabled if there are no valid credit cards" do
        expect(page.find('#place-order-button')[:disabled]).to be

        choose "Pay by Credit Card"

        expect(page.find('#place-order-button')[:disabled]).to be
      end

      it "enables the button if there is at least one valid credit card for the organization" do
        create(:bank_account, :credit_card, bankable: buyer, stripe_id: 'fake stripe id')
        visit cart_path

        expect(page).to have_button("Place Order", disabled: true)

        choose "Pay by Credit Card"

        expect(page).to have_button("Place Order")
      end
    end

  end

  context "using a discount code" do
    context "with an invalid discount code" do
      it "informs the user the code is invalid" do
        fill_in "Discount Code", with: "Super Awesome"
        click_link "Apply"

        expect(page).to have_content("Invalid discount code")

        within("#totals") do
          expect(page).not_to have_content("Discount")
        end
      end
    end

    context "with a valid discount code" do
      let!(:discount) { create(:discount, code: "15off", discount: "15", type: "fixed") }

      it "displays the applied discount and code" do
        fill_in "Discount Code", with: "15off"
        click_link "Apply"

        expect(page).to have_content("Discount applied")

        within("#totals") do
          expect(page).to have_content("Discount")
        end

        expect(cart_totals.subtotal).to have_content("$43.00")
        expect(cart_totals.discount).to have_content("$15.00")
        expect(cart_totals.delivery_fees).to have_content("$10.75")
        expect(cart_totals.total).to have_content("$38.75")
      end
    end

    context "changing the cart after applying a discount" do
      let!(:discount) { create(:discount, code: "15off", discount: "15", type: "fixed", minimum_order_total: 30.00) }

      it "informs the user the discount code is no longer valid" do
        fill_in "Discount Code", with: "15off"
        click_link "Apply"

        expect(page).to have_content("Discount applied")

        go_to_order_page

        Dom::ProductListing.find_by_name("Kale").set_quantity(1)
        expect(Dom::CartLink.first).to have_content("Item updated!")

        cart_link.node.click

        expect(page).to have_content("Discount code requires a minimum of $30.00")

        within("#totals") do
          expect(page).not_to have_content("Discount")
        end
      end
    end

    context "with an order less then the discount minimum" do
      let!(:discount) { create(:discount, code: "15off", discount: "15", type: "fixed", minimum_order_total: 100.00) }

      it "informs the user of the discount code minimum order total" do
        fill_in "Discount Code", with: "15off"
        click_link "Apply"

        expect(page).to have_content("Discount code requires a minimum of $100.00")

        within("#totals") do
          expect(page).not_to have_content("Discount")
        end
      end
    end

    context "with an discount code restricted to order minimum" do
      let!(:discount) { create(:discount, code: "15off", discount: "15", type: "fixed", start_date: 2.days.ago, end_date: 1.day.from_now) }

      it "displays the applied discount and code" do
        discount.update_attribute(:end_date, 1.day.ago)
        fill_in "Discount Code", with: "15off"
        click_link "Apply"

        expect(page).to have_content("Discount code expired")

        within("#totals") do
          expect(page).not_to have_content("Discount")
        end
      end
    end

    context "with a valid discount maxed out on total usage" do
      let!(:discount) { create(:discount, code: "15off", discount: "15", type: "fixed", maximum_uses: 2) }
      let!(:order1) { create(:order, discount: discount) }
      let!(:order2) { create(:order, discount: discount) }

      it "informs the user the code has expired" do
        fill_in "Discount Code", with: "15off"
        click_link "Apply"

        expect(page).to have_content("Discount code expired")

        within("#totals") do
          expect(page).not_to have_content("Discount")
        end
      end
    end

    context "with a valid discount maxed out on organizational usage" do
      let!(:discount) { create(:discount, code: "15off", discount: "15", type: "fixed", maximum_organization_uses: 1) }
      let!(:order1)   { create(:order, organization: buyer, discount: discount) }

      it "informs the user the code has expired" do
        fill_in "Discount Code", with: "15off"
        click_link "Apply"

        expect(page).to have_content("Discount code expired")

        within("#totals") do
          expect(page).not_to have_content("Discount")
        end
      end
    end

    context "buyer organization restrictions" do
      context "with a valid discount restricted to the current buying organization" do
        let!(:discount) { create(:discount, code: "15off", discount: "15", type: "fixed", buyer_organization_id: buyer.id) }

        it "displays the applied discount and code" do
          fill_in "Discount Code", with: "15off"
          click_link "Apply"

          expect(page).to have_content("Discount applied")

          within("#totals") do
            expect(page).to have_content("Discount")
          end

          expect(cart_totals.subtotal).to have_content("$43.00")
          expect(cart_totals.discount).to have_content("$15.00")
          expect(cart_totals.delivery_fees).to have_content("$10.75")
          expect(cart_totals.total).to have_content("$38.75")
        end
      end

      context "with a valid discount restricted to a different buyer organization" do
        let!(:other_org) { create(:organization, :buyer, :single_location) }
        let!(:discount)  { create(:discount, code: "15off", discount: "15", type: "fixed", buyer_organization_id: other_org.id) }
        let!(:order1)    { create(:order, organization: buyer, discount: discount) }

        it "informs the user the code is invalid" do
          fill_in "Discount Code", with: "15off"
          click_link "Apply"

          expect(page).to have_content("Invalid discount code")

          within("#totals") do
            expect(page).not_to have_content("Discount")
          end
        end
      end
    end

    context "seller organization restrictions" do
      context "with a valid discount restricted to the seller items" do
        let!(:discount) { create(:discount, code: "50percent", discount: "50", type: "percentage", seller_organization_id: ada_farms.id) }

        it "displays the applied discount and code" do
          fill_in "Discount Code", with: "50percent"
          click_link "Apply"

          expect(page).to have_content("Discount applied")

          within("#totals") do
            expect(page).to have_content("Discount")
          end

          expect(cart_totals.subtotal).to have_content("$43.00")
          expect(cart_totals.discount).to have_content("$14.38")
          expect(cart_totals.delivery_fees).to have_content("$10.75")
          expect(cart_totals.total).to have_content("$39.37")
        end
      end
    end

    context "market restrictions" do
      context "with a valid discount restricted to the current market" do
        let!(:discount) { create(:discount, code: "15off", discount: "15", type: "fixed", market_id: market.id) }

        it "displays the applied discount and code" do
          fill_in "Discount Code", with: "15off"
          click_link "Apply"

          expect(page).to have_content("Discount applied")

          within("#totals") do
            expect(page).to have_content("Discount")
          end

          expect(cart_totals.subtotal).to have_content("$43.00")
          expect(cart_totals.discount).to have_content("$15.00")
          expect(cart_totals.delivery_fees).to have_content("$10.75")
          expect(cart_totals.total).to have_content("$38.75")
        end
      end

      context "with a valid discount restricted to a different market" do
        let!(:other_market) { create(:market) }
        let!(:discount)  { create(:discount, code: "15off", discount: "15", type: "fixed", market_id: other_market.id) }
        let!(:order1)    { create(:order, organization: buyer, discount: discount) }

        it "informs the user the code is invalid" do
          fill_in "Discount Code", with: "15off"
          click_link "Apply"

          expect(page).to have_content("Invalid discount code")

          within("#totals") do
            expect(page).not_to have_content("Discount")
          end
        end
      end
    end
  end
end
