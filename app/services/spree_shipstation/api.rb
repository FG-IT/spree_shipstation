module SpreeShipstation
  class Api
    END_POINT = 'https://ssapi.shipstation.com'

    attr_reader :api_key, :api_secret, :x_rate_limit_limit, 
                :x_rate_limit_remaining, :x_rate_limit_reset
    
    def initialize(api_key, api_secret)
      @api_key = api_key
      @api_secret = api_secret
    end

    def get_shipments(params)
      path = 'shipments'
      make_call(path, params)
    end

    def make_call(path, params)
      url = "#{END_POINT}/#{path}?#{params.map{|k, v| "#{k}=#{v}"}.join('&')}" 
      res = HTTP.basic_auth(:user => @api_key, :pass => @api_secret).get(url)
      set_rate_limit_info(res.headers.to_h)
      if res.status.success?
        JSON.parse(res.body)
      else
        raise res.body.to_s
      end
    end

    def create_orders(params)
      path = 'orders/createorders'
      post_action(path, params)
    end

    def create_order(params)
      path = 'orders/createorder'
      post_action(path, params)
    end

    def post_action(path, params)
      url = URI("#{END_POINT}/#{path}")
      json_payload = JSON.generate(params)
      request = Net::HTTP::Post.new(url)
      request["Host"] = "ssapi.shipstation.com"
      https = Net::HTTP.new(url.host, url.port)
      https.use_ssl = true
      add_auth(request)
      request['Content-Type'] = 'application/json'
      request.body = json_payload
      set_post_rate_limit_info(request)
      response = https.request(request)
      response.read_body
    end

    private 
    def set_rate_limit_info(headers)
      @x_rate_limit_limit = headers['X-Rate-Limit-Limit'].to_i
      @x_rate_limit_remaining = headers['X-Rate-Limit-Remaining'].to_i
      @x_rate_limit_reset = headers['X-Rate-Limit-Reset'].to_i
    end

    def set_post_rate_limit_info(request)
      request.add_field("X-Rate-Limit-Limit", 40)
      request.add_field("X-Rate-Limit-Remaining", 0)
      request.add_field("X-Rate-Limit-Reset", 20)
    end

    def add_auth(request)
      credentials = "#{@api_key}:#{@api_secret}"
      encoded_credentials = Base64.strict_encode64(credentials)
      request["Authorization"] = "Basic #{encoded_credentials}"
    end
  end
end
