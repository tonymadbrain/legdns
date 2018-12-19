require 'acme-client'
require 'openssl'
require 'date'
require_relative '../config.rb'

class SinatraWorker
  include Sidekiq::Worker
  include  Config
  extend   Config
  sidekiq_options({unique: :all, expiration: 24 * 60 * 60,retry: false})

  config = self.load_config
  %w[dns store notify].each do |type|
    require "#{Dir.pwd}/lib/providers/#{type}/#{config['providers'][type]}.rb"
  end

  def initialize
    config       = load_config
    @le_mailto   = config['acme']['mailto']
    @le_endpoint = config['acme']['endpoint']
    private_key  = OpenSSL::PKey::RSA.new(4096)

    @le_client = Acme::Client.new(
      private_key: private_key,
      endpoint: @le_endpoint,
      connection_options: {
        request: {
          open_timeout: 5,
          timeout: 5
        }
      }
    )
    @dns    = LegdnsProvider.new(config)
    # @store  = LegdnsStore.new(config)
    # @notify = LegdnsNotify.new(config)
  end

  def check_certificate(domains)
    domain         = domains.first
    fullchain_path = "ssl/#{domain}/fullchain.pem"

    if File.exist?(fullchain_path)
      certificate  = OpenSSL::X509::Certificate.new(File.read(fullchain_path))
      cert_domains = certificate.extensions.select {|c| c.to_h['oid'] == 'subjectAltName' }[0]
                       .to_s.split('=')[1]
                       .split(',').map {|a| a.split(':')[1]}
      if Date.parse(certificate.not_after.to_s).mjd - DateTime.now.mjd < 30 ||
        (domains - cert_domains).any?
        return true
      else
        return false
      end
    else
      true
    end
  end

  def check_folder(domain)
    dir = "ssl/#{domain}"

    Dir.mkdir(dir) unless Dir.exists?(dir)
  end

  def perform(ds)
    if @le_client.register(contact: @le_mailto).agree_terms
      logger.info "Letsencrypt client registered #{@le_mailto}"
    else
      logger.error 'Error when try to register in Letsencrypt'
    end

    Dir.mkdir 'ssl' unless Dir.exists?('ssl')

    ds.each do |domains|
      main_domain = domains.first

      logger.info "Check #{main_domain}"

      if check_certificate(domains)
        logger.info "Need renew for #{main_domain} chain"

        check_folder(main_domain)

        domains.each do |domain|
          le_authorization = @le_client.authorize(domain: domain)
          le_challenge     = le_authorization.dns01

          @dns.upsert(domain, le_challenge.record_content)

          if le_challenge.request_verification
            le_status = ''
            until le_status == 'valid'
              le_status = le_challenge.verify_status

              if le_status == 'invalid'
                logger.error "#{le_authorization.dns01.error}"
              end

              unless le_status == 'valid'
                logger.info "Waiting for LetsEncrypt to complete for #{domain}"
                sleep 5
              end
            end
          else
            logger.error "#{le_challenge.error}"
          end
        end

        le_certificate = @le_client.new_certificate(
          Acme::Client::CertificateRequest.new(names: domains)
        )

        if File.write("ssl/#{main_domain}/privkey.pem", le_certificate.request.private_key.to_pem)
          logger.info "Writed privkey.pem file for #{main_domain}"
        else
          logger.error "Error when trying to write privket.pem for #{main_domain}"
        end

        if File.write("ssl/#{main_domain}/fullchain.pem", le_certificate.fullchain_to_pem)
          logger.info "Writed fullchain.pem file for #{main_domain}"
        else
          logger.error "Error when trying to write fullchain.pem for #{main_domain}"
        end

        @dns.cleanup(domains)
      else
        logger.info "No reason to renew for #{main_domain}"
      end
    end
  end
end
