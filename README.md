# Httpsql

[![Gem Version](https://badge.fury.io/rb/httpsql.png)](http://badge.fury.io/rb/httpsql)
[![Build Status](https://travis-ci.org/Adaptly/httpsql.png)](https://travis-ci.org/Adaptly/httpsql)
[![Code Climate](https://codeclimate.com/github/Adaptly/httpsql.png)](https://codeclimate.com/github/Adaptly/httpsql)
[![Dependency Status](https://gemnasium.com/Adaptly/httpsql.png)](https://gemnasium.com/Adaptly/httpsql)
[![Coverage Status](https://coveralls.io/repos/Adaptly/httpsql/badge.png)](https://coveralls.io/r/Adaptly/httpsql)

Httpsql is a module, designed to be included in [Active Record](http://api.rubyonrails.org/classes/ActiveRecord/Base.html) 
models exposed by [grape](https://github.com/intridea/grape). Once the module is
included, a given model can respond directly to query params passed to it, using
`where_params_eq`. You can also constrain the fields returned by the model,
using the `fields` query parameter.

Httpsql uses [ARel](http://www.slideshare.net/flah00/activerecord-arel) to
generate queries and exposes ARel's methods via query params. The supported ARel 
methods are eq, not_eq, matches, does_not_match, gt, gteq, lt, lteq.

Httpsql also generates documentaion for endpoints, which can be easily merged
into your existing documentation (`#route_params`).

Httpsql reserves one parameter, access_token. If your model has a field called
access_token, you'll need to rename it.

## Installation

Add this line to your application's Gemfile:

    gem 'httpsql'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install httpsql

## Usage

Assume you have a model, widget, whose fields are id, int_field, string_field, created_at, updated_at.

    create_table "widgets", :force => true do |t|
      t.integer  "int_field"
      t.float    "dec_field"
      t.string   "string_field"
      t.datetime "created_at", :null => false
      t.datetime "updated_at", :null => false
    end

### model.rb

    class Widget < ActiveRecord::Base
      include Httpsql
      attr_accessible :int_field, :dec_field, :string_field
    end

### api.rb

    class Api < Grape::API
      version 'v1'
      logger Rails.logger
      default_format :json

      resource :widgets do
        desc 'Get all widgets', {
          optional_params: Widget.route_params
        }
        get '/' do
          present Widget.where_params_eq(params)
        end
      end
    end

### config.ru

    api = Rack::Builder.new do
      run Api
    end
    run Rack::URLMap.new \
      '/' => YourApp::Application,
      '/api' => api

Now you're able to run your app

    rails s

Query your new API

    curl 'http://localhost:3000/api/v1/widgets'
    SELECT * FROM widgets

    curl 'http://localhost:3000/api/v1/widgets?id=1'
    SELECT * FROM widgets WHERE id = 1

    curl 'http://localhost:3000/api/v1/widgets?id[]=1&id[]=2'
    SELECT * FROM widgets WHERE id IN (1,2)

    curl 'http://localhost:3000/api/v1/widgets?id.gt=10&id.lt=100'
    SELECT * FROM widgets WHERE id > 10 AND id < 100

    curl 'http://localhost:3000/api/v1/widgets?id[]=1&id[]=2&created_at.gt=2013-06-01'
    SELECT * FROM widgets WHERE id IN (1,2) AND created_at > '2013-06-01'

    curl 'http://localhost:3000/api/v1/widgets?id[]=1&id[]=2&created_at.gt=2013-06-01&fields[]=id&fields[]=int_field'
    SELECT id, int_field FROM widgets WHERE id IN (1,2) AND created_at > '2013-06-01'

    curl 'http://localhost:3000/api/v1/widgets?int_field.sum'
    SELECT SUM(int_field) AS int_field FROM widgets

    curl 'http://localhost:3000/api/v1/widgets?int_field.maximum'
    SELECT MAX(int_field) AS int_field FROM widgets

    curl 'http://localhost:3000/api/v1/widgets?int_field.minimum'
    SELECT MIN(int_field) AS int_field FROM widgets

    curl 'http://localhost:3000/api/v1/widgets?dec_field.round=1'
    SELECT ROUND(dec_field, 1) AS dec_field FROM widgets

    curl 'http://localhost:3000/api/v1/describe_api'
    Returns JSON describing the API

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
  * write some god damned tests
4. Run your god damned tests (`rake test`)
5. Push to the branch (`git push origin my-new-feature`)
6. Create new Pull Request
