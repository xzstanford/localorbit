module Metrics
  class PriceHistory < PriceCalculations
    cattr_accessor :history_metrics

    @@history_metrics = {
      total_price_count: {
        calculation: :count,
        scope: BASE_SCOPE,
        group: "markets.id",
        joins: { product: { organization: :markets } },
        model_type: "Market"
      },
      total_price_sum: {
        calculation: :sum,
        calculation_arg: :sale_price,
        scope: BASE_SCOPE,
        group: "markets.id",
        joins: { product: { organization: :markets } },
        model_type: "Market"
      }
    }
  end
end
