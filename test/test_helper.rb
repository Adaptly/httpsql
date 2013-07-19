require 'simplecov'
#SimpleCov.start
require 'coveralls'
Coveralls.wear!

require 'minitest/spec'
require 'minitest/autorun'
require 'active_record'
require 'grape'
require 'httpsql'

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
    created_at text default CURRENT_TIMESTAMP,
    updated_at text default CURRENT_TIMESTAMP,
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

class TestApi < Grape::API
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

