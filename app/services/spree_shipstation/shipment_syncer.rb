module SpreeShipstation
  class ShipmentSyncer
    PAGE_SIZE = 100
    STATE_MAP = {
      pending: :unpaid,
      ready: :awaiting_shipment,
      shipped: :shipped,
      cancelled: :cancelled,
    }

    DATE_FORMAT = '%Y-%m-%d'

    def initialize(shipstation_account)
      @shipstation_account = shipstation_account
      @api_key = shipstation_account.api_key
      @api_secret = shipstation_account.api_secret
      @api_client = SpreeShipstation::Api.new(@api_key, @api_secret)
      @last_create_on = ((@shipstation_account.shipments_sync_until || Spree::Order.minimum(:created_at)) - 2.days).to_formatted_s(:iso8601)
      @page = 1
    end

    def sync
      if @api_key.present? && @api_secret.present?
        params = generate_params
        res = @api_client.get_shipments(params)
        @last_create_on = process_response(res)
        if @last_create_on.present?
          @shipstation_account.update(shipments_sync_until: @last_create_on)
          wait
          sync
        end
      end
    end

    def wait
      if @api_client.x_rate_limit_remaining.try(:<, 5)
        sleep @api_client.x_rate_limit_reset + 1
      else
        sleep 3
      end
    end

    def create_shipment_order_by_number(number)
      return if @api_key.nil? || @api_secret.nil?

      shipment = ::Spree::Shipment.includes([{order: {ship_address: [:state, :country], bill_address: [:state, :country]}, selected_shipping_rate: :shipping_method}, :inventory_units]).ready.where(number: number).last
      return if shipment.blank?

      line_item_ids = ::Spree::InventoryUnit.where(shipment_id: shipment.id).map {|inventory_unit| inventory_unit.line_item_id }
      @line_items = ::Hash[ ::Spree::LineItem.includes([{variant: [{option_values: :option_type}, :product, :images]}, :refund_items]).where(id: line_item_ids).map do |line_item|
        [line_item.id, line_item] 
      end ]
      create_shipstation_order_by_shipments([shipment])
    end

    def create_shipment_orders
      return if @api_key.nil? || @api_secret.nil?

      ::Spree::ShipstationOrder.where(order_id: nil, needed: true).find_in_batches(batch_size: 1000) do |shipstation_orders|
        shipment_ids = shipstation_orders.pluck(:shipment_id)
        shipments = ::Spree::Shipment.includes([{order: {ship_address: [:state, :country], bill_address: [:state, :country]}, selected_shipping_rate: :shipping_method}, :inventory_units]).ready.where(id: shipment_ids).all
        next if shipments.blank?

        line_item_ids = ::Spree::InventoryUnit.where(shipment_id: shipment_ids).map {|inventory_unit| inventory_unit.line_item_id }
        line_items = ::Hash[ ::Spree::LineItem.includes([{variant: [{option_values: :option_type}, :product, :images]}, :refund_items]).where(id: line_item_ids).map do |line_item|
          [line_item.id, line_item] 
        end ]

        entries = []
        shipments.each do |shipment|
          order = shipment.order
          lis = shipment.inventory_units.map do |inventory_unit|
            li = line_items.fetch(inventory_unit.line_item_id, nil)
            if li.blank?
              Rails.logger.info("[LineItemNotFound] Shipment: #{shipment.number}, LineItemID: #{inventory_unit.line_item_id}")
              next
            end
            if li.try(:refund_items).present?
              Rails.logger.info("[LineItemRefuned] Shipment: #{shipment.number}, LineItemID: #{inventory_unit.line_item_id}")
              next
            end
            # next if li.blank? || li.try(:refund_items).present?
            li
          end.compact
          next if lis.blank?

          entries << {
            shipment: shipment,
            shipstation_order_params: {
              orderNumber: shipment.number,
              orderDate: order.completed_at.strftime(DATE_FORMAT),
              customerEmail: order.email,
              orderTotal: order.total,
              taxAmount: order.tax_total,
              shippingAmount: order.ship_total,
              items: get_shipment_items(lis),
              shipTo: convert_address(order.ship_address),
              billTo: convert_address(order.bill_address),
              orderStatus: STATE_MAP[shipment.state.to_sym],
              amountPaid: shipment.order.payment_total
            }
          }
        end

        entries.each_slice(10) do |entries_buf|
          params = entries_buf.map {|entry| entry[:shipstation_order_params] }
          res = create_shipstation_orders(params)

          Rails.logger.info("[ShipstationResponse] #{res}")

          next unless res.present? && res['results']

          shipments_h = ::Hash[ entries_buf.map {|entry| [entry[:shipment].number, entry[:shipment]] } ]
          res['results'].each do |resp|
            shipment = shipments_h.fetch(resp['orderNumber'], nil)
            next if shipment.blank?

            shipment.shipstation_order&.update(order_id: resp['orderId'])
          end

          wait
        end
      end
    end

    def create_shipstation_orders(params)
      @api_client.create_orders(params)
    end

    def create_shipstation_order_by_shipments(shipments)
      params = shipments.map do |shipment|
        get_shipment_params(shipment)
      end
      res = @api_client.create_orders(params)
      update_shipstation_order_ids_by_res(res, shipments) if res && res['results']
      wait
    end

    def generate_params
      p = {
        'page' => @page,
        'pageSize' => PAGE_SIZE,
        'sortBy' => 'createDate',
        'createDateStart' => @last_create_on,
        'createDateEnd' => DateTime.tomorrow.end_of_day.to_formatted_s(:iso8601)
      }
      p['storeId'] = @shipstation_account.shipstation_store_id if @shipstation_account.shipstation_store_id.present?
      p
    end

    def update_shipstation_order_ids_by_res(res, shipments)
      shipments.each do |shipment|
        result = res['results'].find { |result| result['orderNumber'] == shipment.number }
        shipment.shipstation_order.update(order_id: result['orderId']) if result && result['success']
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

    # def get_shipment_params(shipment)
    #   order = shipment.order
    #   {
    #     orderNumber: shipment.number,
    #     orderDate: order.completed_at.strftime(DATE_FORMAT),
    #     customerEmail: order.email,
    #     orderTotal: order.total,
    #     taxAmount: order.tax_total,
    #     shippingAmount: order.ship_total,
    #     items: get_shipment_items(shipment),
    #     shipTo: convert_address(order.ship_address),
    #     billTo: convert_address(order.bill_address),
    #     orderStatus: STATE_MAP[shipment.state.to_sym],
    #     amountPaid: shipment.order.payment_total
    #   }
    # end

    def process_response(res)
      res['shipments']&.each do |ss_shipment|
        spree_shipment = Spree::Shipment.find_by(number: ss_shipment['orderNumber'])
        next if spree_shipment.blank?
        attrs = { actual_cost: ss_shipment['shipmentCost'] }
        attrs[:carrier] = get_carrier(ss_shipment['carrierCode'], ss_shipment['serviceCode']) if spree_shipment.carrier.blank?
        attrs[:tracking] = ss_shipment['trackingNumber'] if spree_shipment.tracking.blank?
        begin
          spree_shipment&.update_attributes_and_order(attrs)
        rescue
          Rails.logger.warn("[ShipmentUpdateTrackingFailed] Number: #{ss_shipment['orderNumber']}, Attrs: #{attrs}")
        end
      end
      res['shipments']&.size == PAGE_SIZE ? res['shipments']&.last&.try(:[], 'createDate') : nil
    end
    
    def get_carrier(carrier_code, service_code)
      if carrier_code == 'stamps_com' && service_code.start_with?('usps_')
        'USPS'
      else
        carrier_code.upcase
      end
    end
  end
end
