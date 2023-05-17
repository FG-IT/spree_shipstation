module Spree
  class ShipstationOrder < ApplicationRecord
    belongs_to :shipment, foreign_key: :shipment_id, class_name: 'Spree::Shipment'
  end
end
