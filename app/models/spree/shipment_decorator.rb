# frozen_string_literal: true

module Spree
  module ShipmentDecorator
    def self.prepended(base)
      base.singleton_class.prepend ClassMethods
      base.has_one :shipstation_order, foreign_key: :shipment_id, class_name: 'Spree::ShipstationOrder', dependent: :destroy
    end

    module ClassMethods
      def exportable(need_order_approval = false)
        query = order(:updated_at)
          .joins(:order)
          .merge(::Spree::Order.complete)
        query = query.merge(::Spree::Order.where.not(approved_at: nil)) if need_order_approval

        # if the payment is authed, but not caputred yet, the shipment status is pending.
        query = query.where(spree_shipments: {state: ["ready", "pending"]})

        # unless SpreeShipstation.configuration.capture_at_notification
        #   query = query.where(spree_shipments: {state: ["ready", "canceled"]})
        # end

        # unless SpreeShipstation.configuration.export_canceled_shipments
        #   query = query.where.not(spree_shipments: {state: "canceled"})
        # end

        query
      end

      def between(from, to)
        condition = <<~SQL.squish
          (spree_shipments.updated_at > :from AND spree_shipments.updated_at < :to) OR
          (spree_orders.updated_at > :from AND spree_orders.updated_at < :to)
        SQL

        joins(:order).where(condition, from: from, to: to)
      end
    end

    ::Spree::Shipment.prepend self
  end
end
