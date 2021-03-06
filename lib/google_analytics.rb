#
# Taken from https://github.com/hybridgroup/gabba and slightly modified to make the HTTP request in a
# separate thread, and to have a more intelligible namespace.
#

require "uri"
require "net/http"
require "cgi"

module GoogleAnalytics
  class NoGoogleAnalyticsAccountError < RuntimeError; end
  class NoGoogleAnalyticsDomainError < RuntimeError; end
  class GoogleAnalyticsNetworkError < RuntimeError; end

  class GoogleAnalytics
    GOOGLE_HOST = "www.google-analytics.com"
    BEACON_PATH = "/__utm.gif"
    USER_AGENT = "TextMateVim"

    attr_accessor :utmwv, :utmn, :utmhn, :utmcs, :utmul, :utmdt, :utmp, :utmac, :utmt, :utmcc, :user_agent

    def initialize(ga_acct, domain, agent = USER_AGENT)
      @utmwv = "4.4sh" # GA version
      @utmcs = "UTF-8" # charset
      @utmul = "en-us" # language

      @utmn = rand(8999999999) + 1000000000
      @utmhid = rand(8999999999) + 1000000000

      @utmac = ga_acct
      @utmhn = domain
      @user_agent = agent
    end

    def page_view(title, page, utmhid = rand(8999999999) + 1000000000)
      check_account_params
      hey(page_view_params(title, page, utmhid))
    end

    def event(category, action, label = nil, value = nil, utmhid = rand(8999999999) + 1000000000)
      check_account_params
      hey(event_params(category, action, label, value, utmhid))
    end

    def page_view_params(title, page, utmhid = rand(8999999999) + 1000000000)
      {
        :utmwv => @utmwv,
        :utmn => @utmn,
        :utmhn => @utmhn,
        :utmcs => @utmcs,
        :utmul => @utmul,
        :utmdt => title,
        :utmhid => utmhid,
        :utmp => page,
        :utmac => @utmac,
        :utmcc => @utmcc || cookie_params
      }
    end

    def event_params(category, action, label = nil, value = nil, utmhid = rand(8999999999) + 1000000000)
      {
        :utmwv => @utmwv,
        :utmn => @utmn,
        :utmhn => @utmhn,
        :utmt => 'event',
        :utme => event_data(category, action, label, value),
        :utmcs => @utmcs,
        :utmul => @utmul,
        :utmhid => utmhid,
        :utmac => @utmac,
        :utmcc => @utmcc || cookie_params
      }
    end

    def event_data(category, action, label = nil, value = nil)
      data = "5(#{category}*#{action}" + (label ? "*#{label})" : ")")
      data += "(#{value})" if value
      data
    end

    # create magical cookie params used by GA for its own nefarious purposes
    def cookie_params(utma1 = rand(89999999) + 10000000, utma2 = rand(1147483647) + 1000000000, today = Time.now)
      "__utma=1.#{utma1}00145214523.#{utma2}.#{today.to_i}.#{today.to_i}.15;+__utmz=1.#{today.to_i}.1.1.utmcsr=(direct)|utmccn=(direct)|utmcmd=(none);"
    end

    # sanity check that we have needed params to even call GA
    def check_account_params
      raise NoGoogleAnalyticsAccountError unless @utmac
      raise NoGoogleAnalyticsDomainError unless @utmhn
    end

    # makes the tracking call to Google Analytics
    def hey(params)
      Thread.new do
        begin
          query = params.map {|k,v| "#{k}=#{CGI.escape(v.to_s)}" }.join('&')
          response = Net::HTTP.start(GOOGLE_HOST) do |http|
            request = Net::HTTP::Get.new("#{BEACON_PATH}?#{query}")
            request["User-Agent"] = URI.escape(user_agent)
            request["Accept"] = "*/*"
            http.request(request)
          end
          raise GoogleAnalyticsNetworkError unless response.code == "200"
          response
        rescue => e
          # NOTE(philc): Ignoring exceptions for now.
          # log e.inspect
        end
        Thread.current.kill
      end
    end
  end

end
