module Spree
  class ShipstationAccountStockLocation < ApplicationRecord
    belongs_to :shipstation_account
    belongs_to :stock_location
  end
end
