require 'sinatra'
require 'sinatra/reloader'
require 'sidekiq'
require 'sidekiq/api'

Dir.glob("#{Dir.pwd}/lib/workers/*.rb").each { |file| require file }

class Legdns < Sinatra::Base

  Dir.glob("#{Dir.pwd}/lib/helpers/*.rb").each { |file| require file }

  configure :development do
    register Sinatra::Reloader
  end

  before do
    request.path_info.sub! %r{/$}, ''
    if settings.production?
      status 405 unless request.secure?
    end
  end

  not_found do
    json_error("Doesn't know this ditty", 404)
  end

  post '/cert' do
    params = JSON.parse(request.body.read).inject({}){ |h,(k,v)| h[k.to_sym] = v; h }

    if SinatraWorker.perform_async(params[:domains])
      'OK'
    else
      json_error('Something goes wrong', 500)
    end
  end

  get '/cert' do
    domains = params['domains'].split(';').map { |a| a.split(',') }

    if SinatraWorker.perform_async(domains)
      'OK'
    else
      json_error('Something goes wrong', 500)
    end
  end
end
