require 'minitest/spec'
require 'minitest/autorun'
require 'active_record'
require 'httpsql'

ActiveRecord::Base.configurations[:test] = {adapter:  'sqlite3', database: 'tmp/httpsql_test'}
ActiveRecord::Base.establish_connection(ActiveRecord::Base.configurations[:test])
ActiveRecord::Base.connection.execute %Q{ DROP TABLE IF EXISTS foo_models }
ActiveRecord::Base.connection.execute %Q{ 
  CREATE TABLE foo_models (
    id integer,
    int_field integer,
    string_field text,
    access_token text,
    created_at text default CURRENT_TIMESTAMP,
    updated_at text default CURRENT_TIMESTAMP,
    primary key(id)
  );
}
class FooModel < ActiveRecord::Base
  include Httpsql
  attr_accessible :int_field, :string_field, :access_token
end

def generate_models
  FooModel.create!([
    {int_field: 0, string_field: "zero",  access_token: "000"},
    {int_field: 1, string_field: "one",   access_token: "111"},
    {int_field: 2, string_field: "two",   access_token: "222"},
    {int_field: 3, string_field: "three", access_token: "333"},
    {int_field: 4, string_field: "four",  access_token: "444"},
  ])
end

describe Httpsql do
  before :each do
    FooModel.connection.execute %Q{DELETE FROM foo_models}
  end

  it 'selects a model\'s columns from a given hash' do
    ret = FooModel.send(:valid_params, id: 1, int_field: 2, string_field: "foo", access_token: "a", created_at: '2013-01-01T00:00:00', created_at: '2013-01-01T00:00:00', foo: :bar)
    ret.must_equal(id: 1, int_field: 2, string_field: "foo", access_token: "a", created_at: '2013-01-01T00:00:00', created_at: '2013-01-01T00:00:00')
  end

  it 'selects all models' do
    models = generate_models
    FooModel.where_params_eq({}).must_equal models
  end

  it 'selects a specified array of models' do
    models = generate_models
    FooModel.where_params_eq("int_field" => [0, 1]).must_equal models[0..1]
  end

  it 'selects a model, using eq' do
    models = generate_models
    FooModel.where_params_eq("int_field.eq" => 0).must_equal [models[0]]
  end

  it 'selects models, using not_eq' do
    models = generate_models
    FooModel.where_params_eq("int_field.not_eq" => 0).must_equal models[1..-1]
  end

  it 'selects a model, using matches' do
    models = generate_models
    FooModel.where_params_eq("string_field.matches" => "%hre%").must_equal [models[3]]
  end

  it 'selects models, using does_not_match' do
    models = generate_models
    FooModel.where_params_eq("string_field.does_not_match" => "%ero").must_equal models[1..-1]
  end
  it 'selects models, using gt' do
    models = generate_models
    FooModel.where_params_eq("int_field.gt" => 1).must_equal models[2..-1]
  end

  it 'selects models, using gteq' do
    models = generate_models
    FooModel.where_params_eq("int_field.gteq" => 2).must_equal models[2..-1]
  end

  it 'select models, using lt' do
    models = generate_models
    FooModel.where_params_eq("int_field.lt" => 1).must_equal [models[0]]
  end

  it 'selects models, using lteq' do
    models = generate_models
    FooModel.where_params_eq("int_field.lteq" => 2).must_equal models[0..2]
  end

  it 'selects models, using two ARel methods' do
    models = generate_models
    FooModel.where_params_eq("int_field.gteq" => 1, "id.gt" => 4).must_equal [models[4]]
  end

  it 'ignores access_token' do
    models = generate_models
    FooModel.where_params_eq("access_token" => "111").must_equal models
  end

  it 'ignores access_token dot notation' do
    models = generate_models
    FooModel.where_params_eq("access_token.eq" => "111").must_equal models
  end

  it 'selects a model with specified fields' do
    generate_models
    model = FooModel.select([:int_field, :id]).where(int_field: 0)
    FooModel.where_params_eq("int_field.eq" => 0, field: [:int_field, :id]).must_equal model
  end

  it 'generates the correct documentation' do
    FooModel.route_params.must_equal({
      "id"           => {:type => "integer", :desc => "id",            :primary => true},
      "int_field"    => {:type => "integer", :desc => "int_field",     :primary => false},
      "string_field" => {:type => "text",    :desc => "string_field",  :primary => false},
      "access_token" => {:type => "text",    :desc => "access_token",  :primary => false},
      "created_at"   => {:type => "text",    :desc => "created_at",    :primary => false},
      "updated_at"   => {:type => "text",    :desc => "updated_at",    :primary => false},
      "field"        => {:type => "array",   :desc => "select fields", :primary => false}}
    )
  end
end
