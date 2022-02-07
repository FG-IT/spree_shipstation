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

    private 
      def set_rate_limit_info(headers)
        @x_rate_limit_limit = headers['X-Rate-Limit-Limit'].to_i
        @x_rate_limit_remaining = headers['X-Rate-Limit-Remaining'].to_i
        @x_rate_limit_reset = headers['X-Rate-Limit-Reset'].to_i
      end
  end
end