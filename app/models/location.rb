class Location < ActiveRecord::Base
  belongs_to :organization, inverse_of: :locations

  validates :name, presence: true, uniqueness: { scope: :organization_id }
  validates :address, :city, :state, :zip, :organization, presence: true

  def self.alphabetical_by_name
    order(name: :asc)
  end
end
