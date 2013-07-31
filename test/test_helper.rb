require 'simplecov'
#SimpleCov.start
require 'coveralls'
Coveralls.wear!

require 'minitest/spec'
require 'minitest/autorun'
require 'active_record'
require 'grape'
require 'httpsql'
require 'timecop'
require 'rack/test'

ActiveRecord::Base.configurations[:test] = {adapter:  'sqlite3', database: 'tmp/httpsql_test'}
ActiveRecord::Base.establish_connection(ActiveRecord::Base.configurations[:test])
ActiveRecord::Base.connection.execute %Q{ DROP TABLE IF EXISTS foo_models }
ActiveRecord::Base.connection.execute %Q{ 
  CREATE TABLE foo_models (
    id integer,
    int_field integer,
    dec_field decimal,
    string_field text,
    access_token text,
    created_at datetime default CURRENT_TIMESTAMP,
    updated_at datetime default CURRENT_TIMESTAMP,
    primary key(id)
  );
}

ActiveRecord::Base.connection.execute %Q{ DROP TABLE IF EXISTS bar_models }
ActiveRecord::Base.connection.execute %Q{ 
  CREATE TABLE bar_models (
    id integer,
    foo_model_id integer,
    string_field text,
    primary key(id)
  );
}

ActiveRecord::Base.connection.execute %Q{ DROP TABLE IF EXISTS baz_models }
ActiveRecord::Base.connection.execute %Q{ 
  CREATE TABLE baz_models (
    id integer,
    foo_model_id integer,
    string_field text,
    primary key(id)
  );
}

ActiveRecord::Base.connection.execute %Q{ DROP TABLE IF EXISTS bam_models }
ActiveRecord::Base.connection.execute %Q{ 
  CREATE TABLE bam_models (
    id integer,
    bar_model_id integer,
    string_field text,
    primary key(id)
  );
}

class FooModel < ActiveRecord::Base
  include Httpsql
  has_one :bar_model
  has_many :baz_models
end
ActiveRecord::Base.include_root_in_json = false

class BarModel < ActiveRecord::Base
  include Httpsql
  belongs_to :foo_model
  has_many :bam_models
end

class BazModel < ActiveRecord::Base
  include Httpsql
  belongs_to :foo_model
end

class BamModel < ActiveRecord::Base
  include Httpsql
  belongs_to :bar_model
end

module ModelHelpers

  def generate_foo_models
    FooModel.create!([
      {int_field: 0, dec_field: 0.01, string_field: "zero",  access_token: "000"},
      {int_field: 1, dec_field: 1.01, string_field: "one",   access_token: "111"},
      {int_field: 2, dec_field: 2.01, string_field: "two",   access_token: "222"},
      {int_field: 3, dec_field: 3.01, string_field: "three", access_token: "333"},
      {int_field: 4, dec_field: 4.01, string_field: "four",  access_token: "444"},
    ])
  end
  
  def generate_bar_models
    BarModel.create!([
      {foo_model_id: 1, string_field: "zero"},
      {foo_model_id: 2, string_field: "one"},
    ])
  end
  
  def generate_baz_models
    BazModel.create!([
      {foo_model_id: 1, string_field: "zeropointzero"},
      {foo_model_id: 1, string_field: "zeropointone"},
      {foo_model_id: 2, string_field: "onepointzero"},
      {foo_model_id: 2, string_field: "onepointone"},
    ])
  end

  def clean_models
    %w(foo_models bar_models baz_models).each do |t|
      FooModel.connection.execute %Q{DELETE FROM #{t}}
    end
  end
end



class TestApi < Grape::API
  version 'v1'
  default_format :json
  resource :foo_models do
    desc 'foo models index'
    params do
      FooModel.grape_documentation(self)
    end
    get '/' do
      FooModel.with_params(params)
    end
  end

  resource :baz_models do
  desc 'baz models index'
  params do
    BazModel.grape_documentation(self)
  end
  get '/' do
    BazModel.with_params(params)
    end
  end
end

module ApiHelpers
  include Rack::Test::Methods
  def app
    api = Rack::Builder.new do
      run TestApi
    end
    Rack::URLMap.new('/api' => api)
  end

  def time
    Time.current.utc.strftime("%Y-%m-%d %H:%M:%S")
  end
end


