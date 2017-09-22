# LEGDNS

It is a service for acquire ssl certificates from [Let's Encrypt](https://letsencrypt.org/) thorugh DNS method in automatic way.

## TODO

* Fill the readme
* More DNS providers

## How to start

### Install

Requirements:

Ruby 2.3.0 or higher
Redis 2.8 or higher

Installation:

1. Fork or clone this repo
2. Run `bundle install`

### Setup ENV

Export environment variables:

* LEGDNS_DNS_PROVIDER
* LEGDNS_MAILTO
* LEGDNS_ENDPOINT
* LEGDNS_AWS_REGION
* LEGDNS_AWS_ACCESS_KEY_ID
* LEGDNS_AWS_SECRET_ACCESS_KEY

### Run sidekiq

```bash
sidekiq -r app.rb
```

If no LEGDN_DNS_PROVIDER provided application will use default provider - aws.

### Run application

```bash
bundle exec rackup -p 3000
```

### Send request

To acquire certificate you need to send HTTP POST request to the service with json data like:

```bash
curl -X POST -is 'http://127.0.0.1:3000/cert' -d '{"domains":[["example.com", "a.example.com", "b.example.com"], ["example.net"]]}'
```

Where first domain will be the main.

