module Spree
  class ShipstationOrder < ApplicationRecord
    belongs_to :shipment, foreign_key: :shipment_id, class_name: 'Spree::Shipment'
    belongs_to :shipstation_account

    STATE_MAP = {
      pending: :awaiting_payment,
      ready: :awaiting_shipment,
      shipped: :shipped,
      canceled: :cancelled
    }

    DATE_FORMAT = '%Y-%m-%d'

    def self.shipstation_orders_data(shipstation_orders)
      custom_datas = self.custom_shipstation_orders_data(shipstation_orders)
      ::Hash[ shipstation_orders.includes([
        {
          shipment: {
            inventory_units: {
              line_item: [
                :refund_items,
                {
                  variant: [
                    {
                      option_values: :option_type,
                      images: :attachment_blob,
                    },
                    :product
                  ]
                }
              ]
            },
            order: {
              ship_address: [:state, :country],
              bill_address: [:state, :country]
            },
            selected_shipping_rate: :shipping_method,
            shipping_rates: :shipping_method
          },
        }
      ]).map do |shipstation_order|
        basic_data = shipstation_order.shipstation_order_data(false)
        custom_data = custom_datas.fetch(shipstation_order.id, nil)
        basic_data.merge!(custom_data) if custom_data.present?

        [shipstation_order.id, basic_data]
      end ]
    end

    def self.custom_shipstation_orders_data(shipstation_orders)
      {}
    end

    def shipstation_order_data(with_custom_data = true)
      order = shipment&.order
      if order.blank? || !order.completed?
        ::Rails.logger.warn("[InvalidShipstationOrder] ShipstationOrderID: #{self.id}, ShipmentID: #{self.shipment_id}")
        return
      end

      lis = shipment.inventory_units.map do |inventory_unit|
        li = inventory_unit.line_item
        next if li.blank? || li.refund_items.present?
        li
      end.compact

      # line_item_ids = shipment.inventory_units.map {|inventory_unit| inventory_unit.line_item_id }
      # line_items = ::Hash[ ::Spree::LineItem.includes([:refund_items, {variant: [{option_values: :option_type, images: :attachment_blob}, :product]}]).where(id: line_item_ids).map do |line_item|
      #   [line_item.id, line_item] 
      # end ]

      # lis = shipment.inventory_units.map do |inventory_unit|
      #   li = line_items.fetch(inventory_unit.line_item_id, nil)
      #   next if li.blank? || li.refund_items.present?
      #   li
      # end.compact
      return if lis.blank?

      unless STATE_MAP.has_key?(shipment.state.to_sym)
        ::Rails.logger.warn("[InvalidShipmentState] Shipment: #{shipment.number}, State: #{shipment.state}")
        return
      end

      if shipment.state == 'pending' && order.approved? && order.state != 'canceled'
        order_status = :awaiting_shipment
      else
        order_status = STATE_MAP[shipment.state.to_sym]
      end

      item = {
        orderNumber: shipment.number,
        orderKey: order_key,
        orderDate: order.completed_at.strftime(DATE_FORMAT),
        customerEmail: order.email,
        orderTotal: order.total,
        taxAmount: order.tax_total,
        shippingAmount: order.ship_total,
        items: get_shipment_items(lis),
        shipTo: format_address(order.ship_address),
        billTo: format_address(order.bill_address),
        orderStatus: order_status,
        amountPaid: order.payment_total,
        requestedShippingService: shipment.shipping_method.try(:name),
      }

      item.merge!(custom_shipstation_order_data) if with_custom_data

      item
    end

    def custom_shipstation_order_data
      {}
    end

    def format_address(address)
      return if address.blank?

      {
        name: "#{address.firstname} #{address.lastname}",
        company: address.company,
        street1: address.address1,
        street2: address.address2,
        street3: nil,
        city: address.city,
        state: address.state ? address.state.abbr : address.state_name,
        country: address.country&.iso,
        postalCode: address.zipcode,
        phone: address.phone
      }
    end

    def get_shipment_items(line_items)
      line_items.map do |line|
        variant = line.variant
        image_url = (variant.images.first || variant.product.images.first).try(:url, :pdp_thumbnail)
        item = {
          sku: variant.sku,
          name: [variant.product.name, variant.options_text].join(" ").try(:[], 0..198),
          imageUrl: image_url.present? ? image_url : '',
          quantity: line.quantity,
          unitPrice: line.price,
        }
        if variant.weight.present? && variant.weight.to_f > 0
          item[:weight] = {
            value: variant.weight.to_f,
            units: ::SpreeShipstation.configuration.weight_units
          }
        end

        if variant.option_values.present?
          item = item.merge({
            options: variant.option_values.map do |value|
              {
                name: value.option_type.presentation,
                value: value.name
              }
            end
          })
        end

        item
      end.compact
    end
  end
end
