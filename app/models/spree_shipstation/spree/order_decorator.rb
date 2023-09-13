module SpreeShipstation
  module Spree
    module OrderDecorator
      def self.prepended(base)
        # base.singleton_class.prepend ClassMethods
        base.has_one :order_address_verification, foreign_key: :order_id, class_name: 'Spree::OrderAddressVerification', dependent: :destroy
      end

      def is_address_verify_pending?
        return false if order_address_verification.blank? || !order_address_verification.verified.nil?

        order_address_verification.message.present? && order_address_verification.message.include?('not yet validated')
      end

      def is_address_verified?
        country_code = ship_address&.country&.iso
        return true if country_code.present? && country_code != 'US'

        return false if order_address_verification.blank?

        order_address_verification.verified
      end

      def is_address_residential?
        return false if order_address_verification.blank?

        order_address_verification.residential
      end
    end
  end
end

::Spree::Order.prepend ::SpreeShipstation::Spree::OrderDecorator
