module SpreeShipstation
  module Spree
    module AddressDecorator
      def self.prepended(base)
        # sometimes, it's necessary to edit order's shipping address. 
        # when shipping address is updated, the order's updated_at should
        # be updated as well, so that when shipstation pulls data next time, 
        # the order's address can be updated to shipstation.
        base.after_update :update_order_updated_at
      end

      def update_order_updated_at
        ::Spree::Order.where(ship_address: self.id).update_all(updated_at: Time.now)
      end
    end
  end
end

::Spree::Address.prepend SpreeShipstation::Spree::AddressDecorator