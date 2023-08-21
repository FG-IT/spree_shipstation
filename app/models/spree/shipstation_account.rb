module Spree
  class ShipstationAccount < Spree::Base
    enum status: { active: 1, inactive: 0 }

    validates :username, presence: true, uniqueness: true
    validates :password, presence: true, length: { minimum: 6 }

    has_many :shipstaion_account_stock_locations, class_name: '::Spree::ShipstationAccountStockLocation', dependent: :destroy
    has_many :stock_locations, through: :shipstaion_account_stock_locations
    accepts_nested_attributes_for :shipstaion_account_stock_locations
    has_many :shipstation_orders

    def stock_location_ids
      self.stock_locations.active.pluck(:id)
    end
  end
end
