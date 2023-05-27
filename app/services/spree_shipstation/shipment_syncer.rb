module SpreeShipstation
  class ShipmentSyncer
    PAGE_SIZE = 500
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

    def wait
      if @api_client.x_rate_limit_remaining.try(:<, 5)
        sleep @api_client.x_rate_limit_reset + 1
      else
        sleep 3
      end
    end

    def create_shipment_orders
      return if @api_key.nil? || @api_secret.nil?

      ::Spree::ShipstationOrder.where(order_key: nil, needed: true, shipstation_account_id: @shipstation_account.id).find_in_batches(batch_size: 1000) do |shipstation_orders|
        process_shipstation_orders(shipstation_orders)
      end
    end

    def update_shipment_orders
      return if @api_key.nil? || @api_secret.nil?

      ::Spree::ShipstationOrder.includes(:shipment).where.not(order_key: nil).where(needed: true, shipstation_account_id: @shipstation_account.id).find_in_batches(batch_size: 1000) do |shipstation_orders|
        process_shipstation_orders(shipstation_orders.select {|sso| sso.shipment.ready_or_pending? })
      end
    end

    def sync_shipments(params={})
      return unless @api_key.present? && @api_secret.present?

      dft_params = {
        page: 1,
        pageSize: PAGE_SIZE,
        shipDateStart: 7.days.ago.strftime('%Y-%m-%d'),
        sortBy: 'ShipDate',
      }

      filter = {}
      filter.merge!(dft_params, params)
      filter[:storeId] = @shipstation_account.shipstation_store_id if @shipstation_account.shipstation_store_id.present?

      while true do
        res = @api_client.list_shipments(filter)
        wait
        break if res.blank? || res['shipments'].blank?

        shipment_numbers = res['shipments'].map {|ss| ss['orderNumber'] }
        shipments_mapping = ::Hash[ ::Spree::Shipment.where(number: shipment_numbers).map {|shipment| [shipment.number, shipment] } ]
        res['shipments'].each do |ss|
          shipment = shipments_mapping.fetch(ss['orderNumber'], nil)
          next if shipment.blank? || (shipment.tracking.present? && shipment.carrier.present? && shipment.actual_cost.present?)

          attrs = { actual_cost: ss['shipmentCost'] }
          attrs[:carrier] = get_carrier(ss['carrierCode'], ss['serviceCode']) if shipment.carrier.blank?
          attrs[:tracking] = ss['trackingNumber'] if shipment.tracking.blank?
          begin
            shipment&.update_attributes_and_order(attrs)
          rescue
            Rails.logger.warn("[ShipmentUpdateTrackingFailed] Number: #{ss['orderNumber']}, Attrs: #{attrs}")
          end
        end

        pages = res.fetch('pages', 1)
        break if filter[:page] >= pages

        filter[:page] += 1
      end
    end

    def sync_shipment_orders(params={})
      dft_params = {
        page: 1,
        pageSize: PAGE_SIZE,
        createDateStart: 7.days.ago.strftime('%Y-%m-%d'),
        sortBy: 'CreateDate',
      }

      filter = {}
      filter.merge!(dft_params, params)
      filter[:storeId] = @shipstation_account.shipstation_store_id if @shipstation_account.shipstation_store_id.present?

      while true do
        res = list_shipstation_orders(filter)
        wait
        break if res.blank? || res['orders'].blank?

        res_orders = ::Hash[ res['orders'].map {|r| [r['orderNumber'], r] } ]
        shipment_numbers = res['orders'].map {|r| r['orderNumber'] }
        shipments = ::Spree::Shipment.where(number: shipment_numbers)
        shipments_mapping = ::Hash[ shipments.map {|shipment| [shipment.id, {shipment: shipment, shipstation: res_orders.fetch(shipment['number'], nil)}] } ]
        
        shipment_ids = shipments.map {|shipment| shipment.id }
        ::Spree::ShipstationOrder.where(shipment_id: shipments_mapping.keys).each do |shipstation_order|
          sm = shipments_mapping.delete(shipstation_order.shipment_id)
          next if sm[:shipstation].blank?

          shipstation_order.update(order_id: sm[:shipstation]['orderId'], order_key: sm[:shipstation]['orderKey'])
        end

        return if shipments_mapping.blank?

        shipstation_orders_arr = shipments_mapping.values.map do |sm|
          next if sm[:shipstation].blank?
          {
            shipment_id: sm[:shipment].id,
            order_id: sm[:shipstation]['orderId'],
            order_key: sm[:shipstation]['orderKey'],
            needed: true,
            created_at: sm[:shipstation]['createDate'],
            updated_at: sm[:shipstation]['modifyDate']
          }
        end.compact
        ::Spree::ShipstationOrder.insert_all(shipstation_orders_arr)

        pages = res.fetch('pages', 1)
        break if filter[:page] >= pages

        filter[:page] += 1
      end
    end

    def clean_shipment_orders(params={})
      dft_params = {
        page: 1,
        pageSize: PAGE_SIZE,
        createDateStart: 7.days.ago.strftime('%Y-%m-%d'),
        sortBy: 'CreateDate',
      }

      filter = {}
      filter.merge!(dft_params, params)
      filter[:storeId] = @shipstation_account.shipstation_store_id if @shipstation_account.shipstation_store_id.present?

      ssas = ::Hash[ ::Spree::ShipstationAccount.active.map {|ssa|[ssa.id, ssa] } ]

      while true do
        res = list_shipstation_orders(filter)
        wait
        break if res.blank? || res['orders'].blank?

        res_orders = ::Hash[ res['orders'].map {|r| [r['orderNumber'], r] } ]
        shipment_numbers = res['orders'].map {|r| r['orderNumber'] }
        shipments = ::Spree::Shipment.where(number: shipment_numbers)
        shipments_mapping = ::Hash[ shipments.map {|shipment| [shipment.id, {shipment: shipment, shipstation: res_orders.fetch(shipment['number'], nil)}] } ]
        
        ::Spree::ShipstationOrder.where(shipment_id: shipments_mapping.keys).each do |shipstation_order|
          sm = shipments_mapping.delete(shipstation_order.shipment_id)
          next if sm[:shipstation].blank?

          if shipstation_order.needed?
            # store_id = sm[:shipstation].fetch('advancedOptions', nil)&.fetch('storeId', nil)
            # ssa = ssas.fetch(shipstation_order.shipstation_account_id, nil)
            # if ssa.present?
            #   if store_id != ssa.shipstation_store_id
            #     # TODO: Update shipstation order
            #   else
            #     shipstation_order.update(order_id: sm[:shipstation]['orderId'], order_key: sm[:shipstation]['orderKey'])
            #   end
            # end
          else
            r = delete_shipstation_order(sm[:shipstation]['orderId'])
            Rails.logger.info("[ShipstationOrderDeletion] Response: #{r}, OrderID: #{sm[:shipstation]['orderId']}, OrderNumber: #{sm[:shipstation][:orderNumber]}")
            wait
          end
        end

        pages = res.fetch('pages', 1)
        break if filter[:page] >= pages

        filter[:page] += 1
      end
    end

    def process_shipstation_orders(shipstation_orders)
      shipment_ids = shipstation_orders.pluck(:shipment_id)
      shipstation_orders_mapping = ::Hash[ shipstation_orders.map {|so| [so.shipment_id, so] } ]
      shipments = ::Spree::Shipment.includes([{order: {ship_address: [:state, :country], bill_address: [:state, :country]}, selected_shipping_rate: :shipping_method}, :inventory_units]).ready.where(id: shipment_ids).all
      return if shipments.blank?

      line_item_ids = ::Spree::InventoryUnit.where(shipment_id: shipment_ids).map {|inventory_unit| inventory_unit.line_item_id }
      line_items = ::Hash[ ::Spree::LineItem.includes([{variant: [{option_values: :option_type}, :product, :images]}, :refund_items]).where(id: line_item_ids).map do |line_item|
        [line_item.id, line_item] 
      end ]

      entries = {to_create: [], to_update: []}
      shipments.each do |shipment|
        order = shipment.order
        lis = shipment.inventory_units.map do |inventory_unit|
          li = line_items.fetch(inventory_unit.line_item_id, nil)
          next if li.blank? || li.try(:refund_items).present?
          li
        end.compact
        next if lis.blank?

        item = {
          shipment: shipment,
          shipstation_order_params: {
            # orderId: shipment.id,
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
            amountPaid: shipment.order.payment_total,
            requestedShippingService: shipment.shipping_method.try(:name),
            advancedOptions: {
              customField1: order.number
            }
          }
        }

        if @shipstation_account.shipstation_store_id.present?
          item[:shipstation_order_params][:advancedOptions][:storeId] = @shipstation_account.shipstation_store_id
        end

        shipstation_order = shipstation_orders_mapping[shipment.id]
        if shipstation_order.order_key.present?
          item[:shipstation_order_params][:orderKey] = shipstation_order.order_key
          entries[:to_update] << item
        else
          entries[:to_create] << item
        end
      end

      entries.each do |k, v|
        v.each_slice(10) do |entries_buf|
          params = entries_buf.map {|entry| entry[:shipstation_order_params] }

          if k == :to_create
            res = create_shipstation_orders(params)
          else
            res = update_shipstation_orders(params)
          end
          Rails.logger.debug("[ShipstationResponse] #{res}")

          next unless res.present? && res['results']

          shipments_h = ::Hash[ entries_buf.map {|entry| [entry[:shipment].number, entry[:shipment]] } ]
          res['results'].each do |resp|
            next if resp.blank? || !resp.fetch('success', false)

            shipment = shipments_h.fetch(resp['orderNumber'], nil)
            shipstation_order = shipment&.shipstation_order
            next if shipment.blank? || shipstation_order.blank?

            if shipstation_order.order_id != resp['orderId'] || shipstation_order.order_key != resp['orderKey'])
              shipstation_order.update(order_id: resp['orderId'], order_key: resp['orderKey'])
            end
          end

          wait
        end
      end
    end

    def create_shipstation_orders(params)
      @api_client.create_orders(params)
    end

    def update_shipstation_orders(params)
      @api_client.update_orders(params)
    end

    def list_shipstation_orders(params)
      @api_client.list_orders(params)
    end

    def list_shipstation_shipments(params)
      @api_client.list_shipments(params)
    end

    def delete_shipstation_order(order_id)
      @api_client.delete_order(order_id)
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
    
    def get_carrier(carrier_code, service_code)
      if carrier_code == 'stamps_com' && service_code.start_with?('usps_')
        'USPS'
      else
        carrier_code.upcase
      end
    end
  end
end
