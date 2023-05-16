module Spree
  class ShipstationAccount < Spree::Base
    enum status: { active: 1, inactive: 0 }

    validates :username, presence: true, uniqueness: true
    validates :password, presence: true, length: { minimum: 6 }

    has_many :shipstaion_account_stock_locations, class_name: '::Spree::ShipstationAccountStockLocation', dependent: :destroy
    has_many :stock_locations, through: :shipstaion_account_stock_locations
    accepts_nested_attributes_for :shipstaion_account_stock_locations

    def stock_location_ids
      self.stock_locations.active.pluck(:id)
    end

    class << self
      DATE_FORMAT = '%Y-%m-%d'
      STATE_MAP = {
        pending: :unpaid,
        ready: :awaiting_shipment,
        shipped: :shipped,
        cancelled: :cancelled
      }

      def check_de_forward(shipment)
        shipment.inventory_units.map do |inventory_unit|
          line = @line_items[inventory_unit.line_item_id]
          return false unless line.sku.start_with?('AMZ_DE')
        end
        true
      end

      def update_shipment_forward_status
        ::Spree::Shipment.includes([{order: {ship_address: [:state, :country], bill_address: [:state, :country]}, selected_shipping_rate: :shipping_method}, :inventory_units]).ready.where(forward: nil, shipstation_order_id: nil).order(:created_at).find_in_batches(batch_size: 10) do |shipments|
          shipment_ids = shipments.map {|shipment| shipment.id }

          line_item_ids = ::Spree::InventoryUnit.where(shipment_id: shipment_ids).map {|inventory_unit| inventory_unit.line_item_id }
          @line_items = ::Hash[ ::Spree::LineItem.includes([{variant: [{option_values: :option_type}, :product, :images]}, :refund_items]).where(id: line_item_ids).map do |line_item|
            [line_item.id, line_item] 
          end ]
          shipments.each do |shipment|
            shipment.update(forward: check_de_forward(shipment))
          end
        end
      end

      def create_shipment_orders
        ::Spree::Shipment.includes([{order: {ship_address: [:state, :country], bill_address: [:state, :country]}, selected_shipping_rate: :shipping_method}, :inventory_units]).ready.where(forward: true, shipstation_order_id: nil).find_in_batches(batch_size: 10) do |shipments|
          shipment_ids = shipments.map {|shipment| shipment.id}

          line_item_ids = ::Spree::InventoryUnit.where(shipment_id: shipment_ids).map {|inventory_unit| inventory_unit.line_item_id }
          @line_items = ::Hash[ ::Spree::LineItem.includes([{variant: [{option_values: :option_type}, :product, :images]}, :refund_items]).where(id: line_item_ids).map do |line_item|
            [line_item.id, line_item] 
          end ]
          create_shipstation_order_by_shipments(shipments)
        end
      end

      def create_shipment_orders_by_number(number)
        shipment = ::Spree::Shipment.includes([{order: {ship_address: [:state, :country], bill_address: [:state, :country]}, selected_shipping_rate: :shipping_method}, :inventory_units]).ready.where(number: number)

        line_item_ids = ::Spree::InventoryUnit.where(shipment_id: shipment.id).map {|inventory_unit| inventory_unit.line_item_id }
        @line_items = ::Hash[ ::Spree::LineItem.includes([{variant: [{option_values: :option_type}, :product, :images]}, :refund_items]).where(id: line_item_ids).map do |line_item|
          [line_item.id, line_item] 
        end ]
        create_shipstation_order_by_shipments([shipment])
      end

      def api_client
        shipstation_account ||= ::Spree::ShipstationAccount.where(username: 'everymarket').last
        api_key ||= shipstation_account.api_key
        api_secret ||= shipstation_account.api_secret
        api_client ||= ::SpreeShipstation::Api.new(api_key, api_secret)
        api_client
      end

      def create_shipstation_order_by_shipments(shipments)
        params = shipments.map do |shipment|
          get_shipment_params(shipment)
        end
        res = api_client.create_orders(params)
        update_shipments_by_res(res, shipments)
      end

      def update_shipments_by_res(res, shipments)
        shipments.each do |shipment|
          result = res&['results']&.find { |result| result['orderNumber'] == shipment.number }
          shipment.update(shipstation_order_id: result['orderId']) if result&['success']
        end
      end

      def convert_address(address)
        {
          name: "#{address.firstname} #{address.lastname}",
          company: address.company,
          street1: address.address1,
          street2: address.address2,
          street3: nil,
          city: address.city,
          state: address.state ? address.state.abbr : address.state_name,
          country: 'US',
          residential: true,
          postalCode: address.zipcode,
          phone: address.phone
        }
      end

      def convert_complete_time_to_date(complete_time)
        time = Time.new(complete_time)
        time.strftime('%Y-%m-%d')
      end

      def get_shipment_items(shipment)
        shipment.inventory_units.map do |inventory_unit|
          line = @line_items[inventory_unit.line_item_id]
          next if line.try(:refund_items).present?
          variant = line.variant
          image_url = (variant.images.first || variant.product.images.first).try(:url, :pdp_thumbnail)
          item = {
            sku: variant.sku,
            name: [variant.product.name, variant.options_text].join(" ").try(:[], 0..198),
            imageUrl: image_url.present? ? image_url : '',
            weight: {
              value: variant.weight.to_f,
              units: SpreeShipstation.configuration.weight_units
            },
            quantity: line.quantity,
            unitPrice: line.price,
          }

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
        end
      end

      def get_shipment_params(shipment)
        order = shipment.order
        {
          orderNumber: shipment.number,
          orderDate: order.completed_at.strftime(DATE_FORMAT),
          customerEmail: order.email,
          orderTotal: order.total,
          taxAmount: order.tax_total,
          shippingAmount: order.ship_total,
          items: get_shipment_items(shipment),
          shipTo: convert_address(order.ship_address),
          billTo: convert_address(order.bill_address),
          orderStatus: STATE_MAP[shipment.state.to_sym],
          amountPaid: shipment.order.payment_total
        }
      end
    end
  end
end
