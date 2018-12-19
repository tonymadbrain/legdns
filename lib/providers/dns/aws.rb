require 'aws-sdk'
require 'logger'

class LegdnsProvider
  def initialize
    @logger                 = Logger.new STDOUT
    @logger.level           = Logger::INFO
    @logger.datetime_format = '%Y-%m-%d %H:%M '

    @aws_region = ENV.fetch('LEGDNS_AWS_REGION')
    @aws_access = ENV.fetch('LEGDNS_AWS_ACCESS_KEY_ID')
    @aws_secret = ENV.fetch('LEGDNS_AWS_SECRET_ACCESS_KEY')

    Aws.config.update({
                        region: @aws_region,
                        credentials: Aws::Credentials.new(@aws_access, @aws_secret)
                      })
    @r53_client = Aws::Route53::Client.new
  end

  def upsert(domain, record_content)
    r53_hosted_zone = get_hosted_zone(domain)

    r53_changes = []
    r53_changes << {
      action: 'UPSERT',
      resource_record_set: {
        name: "_acme-challenge.#{domain}.",
        type: 'TXT',
        ttl: 60,
        resource_records: [
          value: "\"#{record_content}\""
        ]
      }
    }
    r53_response = @r53_client.change_resource_record_sets(
      hosted_zone_id: r53_hosted_zone.id,
      change_batch: {
        changes: r53_changes
      }
    )

    r53_status = ''
    until r53_status == 'INSYNC'
      r53_response = @r53_client.get_change(id: r53_response.change_info.id)
      r53_status   = r53_response.change_info.status

      unless r53_status == 'INSYNC'
        @logger.info  "Waiting for DNS change to complete for #{domain}"
        sleep 5
      end
    end
  end

  def cleanup(domains)
    domains.each do |domain|
      @logger.info "Cleanup DNS records for #{domain}"

      r53_hosted_zone = get_hosted_zone(domain)

      @r53_client.list_resource_record_sets({
                                              hosted_zone_id: r53_hosted_zone.id
                                            }).resource_record_sets.select do |rs|
        rs[:type] == 'TXT' && rs[:name] == "_acme-challenge.#{domain}."
      end.each do |record_set|
        @r53_client.change_resource_record_sets({
                                                  hosted_zone_id: r53_hosted_zone.id,
                                                  change_batch: {
                                                    changes:[
                                                      { action: 'DELETE', resource_record_set: record_set }
                                                    ]
                                                  }
                                                })
      end
    end
  end

  private

  def get_hosted_zone(domain)
    hosted_zones = @r53_client.list_hosted_zones_by_name.hosted_zones
    index        = hosted_zones.index { |zone| domain.end_with?(zone.name.chop) }

    @logger.error "Unable to find matching zone on Route 53 for #{domain}" if index.nil?

    hosted_zones[index]
  end
end
