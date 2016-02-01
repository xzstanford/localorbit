class ProductSearchPresenter
  include Search::DateFormat
  include Search::MarketAndOrganization

  attr_reader :start_date, :end_date, :query
  def initialize(query, user, date_search_attr="invoice_due_date")
    @query = Search::QueryDefaults.new(query[:q] || {}, date_search_attr).query
    @user = user

    if @query[:market_id_in].present?
      @filtered_market = @user.markets.find(@query[:market_id_in])
    end

  end
end
