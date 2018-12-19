require 'dotenv/load'

module Config
  def load_config
    prefix  = 'LEGDNS'
    env     = {}
    default = default_config

    env = ENV.each_pair.with_object({}) do |(key, value), data|
      next unless key.start_with?(prefix)

      keys = key.sub(/^#{prefix}_/, '').downcase.split('_')
      data = get_hash(data, keys.shift) while keys.length > 1
      data[keys.first] = value
    end

    default.merge(env)
  end

  private

  def get_hash(from, name)
    (from[name] ||= {})
  end

  def default_config
    default = Hash.new { |hash, key| hash[key] = Hash.new(&hash.default_proc) }

    default['acme']['endpoint']    = 'https://acme-staging.api.letsencrypt.org'
    default['providers']['dns']    = 'aws'
    default['providers']['store']  = 'file'
    default['providers']['notify'] = 'blackhole'

    default
  end
end
