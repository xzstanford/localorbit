module Admin
  class DiscountsController < AdminController
    include StickyFilters

    before_action :require_admin_or_market_manager
    before_action :find_select_data, only: [:new, :create, :show, :update]
    before_action :find_sticky_params, only: :index

    def index
      if params["clear"]
        redirect_to url_for(params.except(:clear))
      else
        visible_markets = find_markets

        base_scope = Discount.includes(:market).visible.where(market_id: visible_markets.map(&:id))

        # For use by the Markets filter pulldown:
        @markets   = base_scope.map(&:market).sort_by(&:name).uniq
        @q         = base_scope.search(@query_params["q"])
        @discounts = @q.result.page(params[:page]).per(@query_params[:per_page])
      end
    end

    def new
      @discount = Discount.new
    end

    def create
      @discount = Discount.new(discount_params)
      if @discount.save
        redirect_to admin_discounts_path, notice: "Successfully created discount."
      else
        flash.now[:alert] = "Error creating discount."
        render "new"
      end
    end

    def show
      @discount = Discount.find(params[:id])
    end

    def update
      @discount = Discount.find(params[:id])
      if @discount.update(discount_params)
        redirect_to admin_discounts_path, notice: "Successfully updated discount."
      else
        flash.now[:alert] = "Error updating discount."
        render "show"
      end
    end

    def destroy
      if Discount.soft_delete(params[:id])
        redirect_to admin_discounts_path, notice: "Successfully removed discount."
      else
        redirect_to admin_discounts_path, alert: "Unable to remove discount."
      end
    end

    def find_markets
      if current_user.admin?
        Market.all
      else
        current_user.managed_markets
      end.order(:name).includes(organization: [:plan]).select {|m| if(m.organization.plan) then m.organization.plan.discount_codes else nil end }
    end

    private

    def discount_params
      params.require(:discount).permit(
        :name,
        :code,
        :market_id,
        :start_date,
        :end_date,
        :type,
        :payer,
        :discount,
        :product_id,
        :category_id,
        :buyer_organization_id,
        :seller_organization_id,
        :minimum_order_total,
        :maximum_order_total,
        :maximum_uses,
        :maximum_organization_uses
      )
    end

    def find_select_data
      @markets = find_markets
      find_products
      find_categories
      find_organizations
    end

    def find_products
      @market_select_options = {}

      org_ids = @markets.map {|m| m.organization_ids }.flatten

      @products = Product.
        joins(:organization).
        where(organization_id: org_ids).
        order("organizations.name, products.name").
        limit(0).
        map {|p| ["#{p.organization.name}: #{p.name}", p.id] }
    end

    def find_categories
      @categories = Category.where(depth: 1).
        order(:name).
        map {|c| [c.name, c.id] }
    end

    def find_organizations
      @organizations = MarketOrganization.
        excluding_deleted.
        not_cross_selling.
        includes(:market, :organization).
        where(market_id: current_user.managed_market_ids).
        order("markets.name ASC, organizations.name ASC").
        map {|mo| ["#{mo.market.name}: #{mo.organization.name}", mo.organization_id] }
    end
  end
end
