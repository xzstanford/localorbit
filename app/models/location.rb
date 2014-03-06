class Location < ActiveRecord::Base
  include SoftDelete
  belongs_to :organization, inverse_of: :locations

  validates :name, presence: true, uniqueness: { scope: :organization_id }
  validates :address, :city, :state, :zip, :organization, presence: true
  validates :default_billing, uniqueness: { scope: :organization_id }, if: "!!default_billing"
  validates :default_shipping, uniqueness: { scope: :organization_id }, if: "!!default_shipping"

  def self.alphabetical_by_name
    order(name: :asc)
  end

  def self.default_billing
    find_by(default_billing: true)
  end

  def self.default_shipping
    find_by(default_shipping: true)
  end
end
