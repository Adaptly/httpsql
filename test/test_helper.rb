require 'minitest/spec'
require 'minitest/autorun'
require 'active_record'
require 'httpsql'

require 'simplecov'
require 'coveralls'
Coveralls.wear!

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
class FooModel < ActiveRecord::Base
  include Httpsql
  #attr_accessible :int_field, :dec_field, :string_field, :access_token
end

