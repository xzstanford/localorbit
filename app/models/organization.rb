class Organization < ActiveRecord::Base
  has_many :market_organizations
  has_many :user_organizations

  has_many :users, through: :user_organizations
  has_many :markets, through: :market_organizations
  has_many :orders, inverse_of: :organization

  has_many :products
  has_many :carts

  has_many :locations, inverse_of: :organization

  validates :name, presence: true

  scope :selling, lambda { where(can_sell: true) }

  accepts_nested_attributes_for :locations

  dragonfly_accessor :photo

  def default_location
    locations.first || locations.build
  end

  def shipping_location
    locations.default_shipping || default_location
  end
end
