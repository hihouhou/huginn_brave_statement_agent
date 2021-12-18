module Agents
  class BraveStatementAgent < Agent
    include FormConfigurable

    can_dry_run!
    no_bulk_receive!
    default_schedule '12h'

    description do
      <<-MD
      The Brave Statement Agent agent fetches statements status from brave server and creates event.

      `changes_only` is only used to emit event about a card's change.

      `csrf_token` / `publishers_session` / `pk_id` are needed for the cooki.

      `debug` is used to verbose mode.

      `expected_receive_period_in_days` is used to determine if the Agent is working. Set it to the maximum number of days
      that you anticipate passing without this Agent receiving an incoming Event.
      MD
    end

    event_description <<-MD
      Events look like this:

          {
            "publisherId": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
            "name": "XXXXXX",
            "email": "XXXXXXXXXXXXXXXXXX",
            "settledTransactions": [
              {
                "channel": "XXXXXXXX",
                "description": "settlement fees",
                "transactionType": "fees",
                "amount": "XXXX",
                "settlementCurrency": null,
                "settlementAmount": null,
                "settlementDestinationType": null,
                "settlementDestination": null,
                "createdAt": "2020-12-09",
                "errors": null
              },
              {
                "channel": "XXXXXXXX",
                "description": "payout for contribution",
                "transactionType": "contribution_settlement",
                "amount": "XXXX",
                "settlementCurrency": "BAT",
                "settlementAmount": "XXXX",
                "settlementDestinationType": "uphold",
                "settlementDestination": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
                "createdAt": "2020-12-09",
                "errors": null
              }
            ],
            "totalEarned": "XXXX",
            "totals": {
              "contributionSettlement": "XXXX",
              "fees": "XXX",
              "referralSettlement": 0,
              "totalBraveSettled": "XXXX",
              "upholdContributionSettlement": 0
            },
            "batTotalDeposited": "XXXX",
            "deposited": {
              "BAT": "XXXX"
            },
            "depositedTypes": {
              "bAT": {
                "contributionSettlement": "XXXX"
              }
            },
            "paymentDate": "2020-12-09",
            "earningPeriod": {
              "startDate": "2020-11-01",
              "endDate": "2020-12-09"
            },
            "settlementDestination": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
            "details": [
              {
                "title": "Brave Settled Contributions",
                "description": "The total amount of contributions paid through Brave managed systems, including auto-contribute and custodial wallets.  5% fee is applied to support Brave Rewards and infrastructure costs.",
                "amount": "XXXX",
                "transactions": [
                  {
                    "channel": "XXXXXXXX",
                    "description": "payout for contribution",
                    "transactionType": "contribution_settlement",
                    "amount": "XXXX",
                    "settlementCurrency": "BAT",
                    "settlementAmount": "XXXX",
                    "settlementDestinationType": "uphold",
                    "settlementDestination": "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
                    "createdAt": "2020-12-09",
                    "errors": null
                  },
                  {
                    "channel": "XXXXXXXX",
                    "description": "settlement fees",
                    "transactionType": "fees",
                    "amount": "XXXX",
                    "settlementCurrency": null,
                    "settlementAmount": null,
                    "settlementDestinationType": null,
                    "settlementDestination": null,
                    "createdAt": "2020-12-09",
                    "errors": null
                  }
                ],
                "type": "contribution_settlement"
              }
            ],
            "isOpen": false,
            "showRateCards": true
          }
    MD

    def default_options
      {
        'csrf_token' => '',
        'publishers_session' => '',
        'pk_id' => '',
        'expected_receive_period_in_days' => '31',
        'changes_only' => 'true',
        'debug' => 'false'
      }
    end

    form_configurable :expected_receive_period_in_days, type: :string
    form_configurable :csrf_token, type: :string
    form_configurable :publishers_session, type: :string
    form_configurable :pk_id, type: :string
    form_configurable :changes_only, type: :boolean
    form_configurable :debug, type: :boolean

    def validate_options
      unless options['csrf_token'].present?
        errors.add(:base, "csrf_token is a required field")
      end

      unless options['publishers_session'].present?
        errors.add(:base, "publishers_session is a required field")
      end

      unless options['pk_id'].present?
        errors.add(:base, "pk_id is a required field")
      end

      if options.has_key?('changes_only') && boolify(options['changes_only']).nil?
        errors.add(:base, "if provided, changes_only must be true or false")
      end

      if options.has_key?('debug') && boolify(options['debug']).nil?
        errors.add(:base, "if provided, debug must be true or false")
      end

      unless options['expected_receive_period_in_days'].present? && options['expected_receive_period_in_days'].to_i > 0
        errors.add(:base, "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this Agent is considered to be not working")
      end
    end

    def working?
      event_created_within?(options['expected_receive_period_in_days']) && !recent_error_logs?
    end

    def check
      fetch
    end

    private

    def fetch
      uri = URI.parse("https://publishers.basicattentiontoken.org/publishers/statements?id=undefined")
      request = Net::HTTP::Get.new(uri)
      request["Authority"] = "publishers.basicattentiontoken.org"
      request["Accept"] = "application/json"
      request["X-Csrf-Token"] = "#{interpolated['csrf_token']}"
      request["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.106 Safari/537.36"
      request["X-Requested-With"] = "XMLHttpRequest"
      request["Sec-Gpc"] = "1"
      request["Sec-Fetch-Site"] = "same-origin"
      request["Sec-Fetch-Mode"] = "cors"
      request["Sec-Fetch-Dest"] = "empty"
      request["Referer"] = "https://publishers.basicattentiontoken.org/publishers/statements?locale=en"
      request["Accept-Language"] = "fr,en-US;q=0.9,en;q=0.8"
      request["Cookie"] = "_pk_testcookie..undefined=1; _pk_id.6.8f93=#{interpolated['pk_id']}; _pk_ses.6.8f93=1; _publishers_session=#{interpolated['publishers_session']}"
      
      req_options = {
        use_ssl: uri.scheme == "https",
      }
  
      response = Net::HTTP.start(uri.hostname, uri.port, req_options) do |http|
        http.request(request)
      end
      
      log "request  status : #{response.code}"

      payload = JSON.parse(response.body)

      if interpolated['debug'] == 'true'
        log payload
      end

      if interpolated['changes_only'] == 'true'
        if payload.to_s != memory['last_status']
          if "#{memory['last_status']}" == ''
            payload['overviews'].each do |tx|
              create_event payload: tx
            end
          else
            last_status = memory['last_status'].gsub("=>", ": ").gsub(": nil", ": null")
            last_status = JSON.parse(last_status)
            payload['overviews'].each do |tx|
              found = false
              if interpolated['debug'] == 'true'
                log "tx"
                log tx
              end
              last_status['overviews'].each do |txbis|
                if tx['paymentDate'] == txbis['paymentDate']
                  found = true
                end
                if interpolated['debug'] == 'true'
                  log "txbis"
                  log txbis
                  log "found is #{found}!"
                end
              end
              if found == false
                if interpolated['debug'] == 'true'
                  log "found is #{found}! so event created"
                  log tx
                end
                create_event payload: tx
              end
            end
          end
          memory['last_status'] = payload.to_s
        end
      else
        create_event payload: payload
        if payload.to_s != memory['last_status']
          memory['last_status'] = payload.to_s
        end
      end
    end
  end
end
