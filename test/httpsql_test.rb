require 'test_helper'

def generate_models
  FooModel.create!([
    {int_field: 0, dec_field: 0.01, string_field: "zero",  access_token: "000"},
    {int_field: 1, dec_field: 1.01, string_field: "one",   access_token: "111"},
    {int_field: 2, dec_field: 2.01, string_field: "two",   access_token: "222"},
    {int_field: 3, dec_field: 3.01, string_field: "three", access_token: "333"},
    {int_field: 4, dec_field: 4.01, string_field: "four",  access_token: "444"},
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

  it 'sums the specified field' do
    models = generate_models
    expected = models.collect(&:int_field).inject(:+)
    FooModel.where_params_eq("int_field.sum" => nil).first.int_field.must_equal expected
  end

  it 'selects the maximum value for the specified field' do
    models = generate_models
    expected = models.collect(&:int_field).max
    FooModel.where_params_eq("int_field.maximum" => nil).first.int_field.must_equal expected
  end

  it 'selects the minimum value for the specified field' do
    models = generate_models
    expected = models.collect(&:int_field).min
    FooModel.where_params_eq("int_field.minimum" => nil).first.int_field.must_equal expected
  end

  it 'generates the specified sql for rounding' do
    models = generate_models
    expected = models.collect(&:dec_field).map{|v| v.round.to_f}
    FooModel.where_params_eq("dec_field.round" => "1").collect(&:dec_field).map{|v| v.to_f}.must_equal expected
  end

  it 'generates the correct documentation' do
    FooModel.route_params.must_equal({
      "id"           => {:type => "integer", :desc => "id",            :primary => true},
      "int_field"    => {:type => "integer", :desc => "int_field",     :primary => false},
      "dec_field"    => {:type => "decimal", :desc => "dec_field",     :primary => false},
      "string_field" => {:type => "text",    :desc => "string_field",  :primary => false},
      "access_token" => {:type => "text",    :desc => "access_token",  :primary => false},
      "created_at"   => {:type => "text",    :desc => "created_at",    :primary => false},
      "updated_at"   => {:type => "text",    :desc => "updated_at",    :primary => false},
      "field"        => {:type => "array",   :desc => "select fields", :primary => false}}
    )
  end
end
