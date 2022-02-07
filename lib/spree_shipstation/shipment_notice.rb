# frozen_string_literal: true

module SpreeShipstation
  class ShipmentNotice
    attr_reader :shipment_number, :shipment_tracking

    class << self
      def from_payload(params, xml_body = nil)
        new(
          shipment_number: params[:order_number],
          shipment_tracking: params[:tracking_number],
          xml_body: xml_body
        )
      end
    end

    def initialize(shipment_number:, shipment_tracking:, xml_body: )
      @shipment_number = shipment_number
      @shipment_tracking = shipment_tracking
      @xml_body = xml_body
    end

    def apply
      unless shipment
        raise ShipmentNotFoundError, shipment
      end
      approve_order
      process_payment
      ship_shipment
      handle_xml_body
      shipment
    end

    def handle_xml_body
      begin
        if @xml_body.present?
          doc = Nokogiri::XML(@xml_body)
          shipping_cost = doc.at_css('ShipNotice ShippingCost')&.content&.to_f
          shipment.update_column(:actual_cost, shipping_cost)
        end
      rescue => e
        Rails.logger.error(e.message)
      end
    end

    private

    def shipment
      @shipment ||= ::Spree::Shipment.find_by(number: shipment_number)
    end

    def approve_order
      return if shipment.order.approved?
      approved_by = ::Spree::User.find_by(id: 48093)
      shipment.order.approved_by(approved_by)
    end

    def process_payment
      return if shipment.order.paid?

      unless SpreeShipstation.configuration.capture_at_notification
        raise OrderNotPaidError, shipment.order
      end

      shipment.order.payments.pending.each do |payment|
        payment.capture!
      rescue ::Spree::Core::GatewayError
        raise PaymentError, payment
      end
    end

    def ship_shipment
      shipment.update_attribute(:tracking, shipment_tracking)

      unless shipment.shipped?
        shipment.reload.ship!
        shipment.touch :shipped_at
        shipment.update!(shipment.order)
      end
    end
  end
end
