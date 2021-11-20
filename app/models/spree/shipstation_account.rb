module Spree
  class ShipstationAccount < Spree::Base
    validates :username, presence: true
    validates :password, presence: true, length: { minimum: 6 }

    has_many :shipstaion_account_stock_locations
    has_many :stock_locations, through: :shipstaion_account_stock_locations
  end
end
