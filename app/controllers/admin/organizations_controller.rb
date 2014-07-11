module Admin
  class OrganizationsController < AdminController
    include StickyFilters

    before_action :require_admin_or_market_manager, only: [:new, :create, :destroy]
    before_action :find_organization, only: [:show, :edit, :update, :delivery_schedules, :market_memberships, :destroy]

    def index
      @query_params = sticky_parameters(request.query_parameters)
      @organizations = current_user.managed_organizations.periscope(@query_params).page(params[:page]).per(@query_params[:per_page])
      find_selling_markets
    end

    def new
      @markets      = current_user.markets
      first_market  = @markets.first

      @organization = Organization.new(
        allow_purchase_orders: first_market.default_allow_purchase_orders,
        allow_credit_cards: first_market.default_allow_credit_cards
      )
    end

    def create
      result = RegisterOrganization.perform(organization_params: organization_params, user: current_user, market_id: params[:initial_market_id])

      if result.success?
        organization = result.organization
        redirect_to [:admin, organization], notice: "#{organization.name} has been created"
      else
        @markets = current_user.markets
        @organization = result.organization
        render action: :new
      end
    end

    def show
    end

    def update
      if @organization.update_attributes(organization_params)
        redirect_to [:admin, @organization], notice: "Saved #{@organization.name}"
      else
        render action: :show
      end
    end

    def destroy
      market_ids = Array.wrap(params[:ids]).map(&:to_i)
      market_ids &= current_user.managed_markets.pluck(:id) unless current_user.admin?

      remove_organization_from_markets = RemoveOrganizationFromMarkets.perform(
        organization: @organization,
        market_ids:   market_ids
      )

      if remove_organization_from_markets.success?
        postfix = (market_ids.count == 1 ? Market.find(market_ids.first).name : "market membership(s)")
        redirect_to [:admin, :organizations], notice: "Removed #{@organization.name} from #{postfix}"
      else
        redirect_to [:admin, :organizations], alert: remove_organization_from_markets.error
      end
    end

    def delivery_schedules
      schedules = find_delivery_schedules
      ids = schedules.values.flatten.map {|schedule| schedule.id.to_s }

      render partial: "delivery_schedules", locals: {delivery_schedules: schedules, selected_ids: ids, product: nil, organization: @organization}
    end

    def market_memberships
      render partial: "market_memberships"
    end

    private

    def organization_params
      params.require(:organization).permit(
        :name,
        :can_sell,
        :show_profile,
        :facebook,
        :twitter,
        :display_facebook,
        :display_twitter,
        :who_story,
        :how_story,
        :photo,
        :allow_purchase_orders,
        :allow_credit_cards,
        :allow_ach,
        :active,
        locations_attributes: [:name, :address, :city, :state, :zip, :phone, :fax]
      )
    end

    def find_organization
      @organization = current_user.managed_organizations.find(params[:id])
    end

    def find_delivery_schedules
      @organization.decorate.delivery_schedules
    end

    def find_selling_markets
      markets = current_user.admin? ? current_user.markets : current_user.managed_markets
      @selling_markets = markets.order(:name).inject([["All", 0]]) {|result, market| result << [market.name, market.id] }
    end
  end
end
