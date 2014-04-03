class OrderItem < ActiveRecord::Base
  attr :inventory, :deliver_on_date

  belongs_to :order, inverse_of: :items
  belongs_to :product
  has_many :lots, inverse_of: :order_item, class: OrderItemLot, autosave: true

  validates :product, presence: true
  validates :name, presence: true
  validates :order, presence: true
  validates :seller_name, presence: true
  validates :quantity, presence: true
  validates :unit, presence: true
  validates :unit_price, presence: true

  validate  :product_availability, on: :create

  before_create :consume_inventory

  def self.create_with_order_and_item(opts={})
    item = opts[:item]
    deliver_on_date = opts[:deliver_on_date]
    order = opts[:order]

    create(
      order: order,
      product: item.product,
      name: item.product.name,
      quantity: item.quantity,
      unit: item.unit,
      unit_price: item.unit_price.sale_price,
      seller_name: item.product.organization.name
    )
  end


  def seller_net_total
    unit_price * quantity - market_seller_fee - local_orbit_seller_fee - payment_seller_fee
  end

  def gross_total
    unit_price * quantity
  end

  def product_availability
    return unless product.present?

    quantity_available = product.lots_by_expiration.available.sum(:quantity)

    if quantity_available < quantity
      errors[:inventory] = "there are only #{quantity_available} #{product.name.pluralize(quantity_available)} available."
    end
  end

  private
  def consume_inventory
    return unless valid?

    quantity_remaining = quantity

    product.lots_by_expiration.available.each do |lot|
      break unless quantity_remaining

      num_to_consume = [lot.quantity, quantity_remaining].min
      lot.decrement(:quantity, num_to_consume)
      lot.save

      lots.build(lot: lot, quantity: num_to_consume)
      quantity_remaining -= num_to_consume
    end
  end
end
