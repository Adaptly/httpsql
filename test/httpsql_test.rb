require 'test_helper'

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

describe Httpsql do
  before :each do
    FooModel.connection.execute %Q{DELETE FROM foo_models}
    FooModel.connection.execute %Q{DELETE FROM bar_models}
    FooModel.connection.execute %Q{DELETE FROM baz_models}
  end

  describe "#httpsql_valid_params" do
    it 'selects a model\'s columns from a given hash' do
      ret = FooModel.send(:httpsql_valid_params, id: 1, int_field: 2, string_field: "foo", access_token: "a", created_at: '2013-01-01T00:00:00', created_at: '2013-01-01T00:00:00', foo: :bar)
      ret.must_equal(id: 1, int_field: 2, string_field: "foo", access_token: "a", created_at: '2013-01-01T00:00:00', created_at: '2013-01-01T00:00:00')
    end

    it 'selects reserved parameters' do
      ret = FooModel.send(:httpsql_valid_params, 'join'=>'foo', 'group'=>'bar', 'order'=>'baz')
      ret.must_equal('join'=>'foo', 'group'=>'bar', 'order'=>'baz')
    end
  end

  describe '#with_params' do
    it 'selects all models' do
      models = generate_foo_models
      FooModel.with_params({}).must_equal models
    end

    it 'selects a specified array of models' do
      models = generate_foo_models
      FooModel.with_params("int_field" => [0, 1]).must_equal models[0..1]
    end

    it 'selects a model, using eq' do
      models = generate_foo_models
      FooModel.with_params("int_field.eq" => 0).must_equal [models[0]]
    end

    it 'selects models, using not_eq' do
      models = generate_foo_models
      FooModel.with_params("int_field.not_eq" => 0).must_equal models[1..-1]
    end

    it 'selects a model, using matches' do
      models = generate_foo_models
      FooModel.with_params("string_field.matches" => "%hre%").must_equal [models[3]]
    end

    it 'selects models, using does_not_match' do
      models = generate_foo_models
      FooModel.with_params("string_field.does_not_match" => "%ero").must_equal models[1..-1]
    end
    it 'selects models, using gt' do
      models = generate_foo_models
      FooModel.with_params("int_field.gt" => 1).must_equal models[2..-1]
    end

    it 'selects models, using gteq' do
      models = generate_foo_models
      FooModel.with_params("int_field.gteq" => 2).must_equal models[2..-1]
    end

    it 'select models, using lt' do
      models = generate_foo_models
      FooModel.with_params("int_field.lt" => 1).must_equal [models[0]]
    end

    it 'selects models, using lteq' do
      models = generate_foo_models
      FooModel.with_params("int_field.lteq" => 2).must_equal models[0..2]
    end

    it 'selects models, using two ARel methods' do
      models = generate_foo_models
      FooModel.with_params("int_field.gteq" => 1, "id.gt" => 4).must_equal [models[4]]
    end

    it 'ignores access_token' do
      models = generate_foo_models
      FooModel.with_params("access_token" => "111").must_equal models
    end

    it 'ignores access_token dot notation' do
      models = generate_foo_models
      FooModel.with_params("access_token.eq" => "111").must_equal models
    end

    it 'selects a model with specified fields' do
      generate_foo_models
      model = FooModel.select([:int_field, :id]).where(int_field: 0)
      FooModel.with_params("int_field.eq" => 0, field: [:int_field, :id]).must_equal model
    end

    it 'sums the specified field' do
      models = generate_foo_models
      expected = models.collect(&:int_field).inject(:+)
      FooModel.with_params("int_field.sum" => nil).first.int_field.must_equal expected
    end

    it 'selects the maximum value for the specified field' do
      models = generate_foo_models
      expected = models.collect(&:int_field).max
      FooModel.with_params("int_field.maximum" => nil).first.int_field.must_equal expected
    end

    it 'selects the minimum value for the specified field' do
      models = generate_foo_models
      expected = models.collect(&:int_field).min
      FooModel.with_params("int_field.minimum" => nil).first.int_field.must_equal expected
    end

    it 'generates the specified sql for rounding' do
      models = generate_foo_models
      expected = models.collect(&:dec_field).map{|v| v.round.to_f}
      FooModel.with_params("dec_field.round" => "1").collect(&:dec_field).map{|v| v.to_f}.must_equal expected
    end

    it 'groups correctly' do
      models = generate_foo_models
      expected = [FooModel.create({created_at: "1900-01-01"}), models.last]
      FooModel.with_params("group" => "created_at").must_equal expected
    end

    it 'orders unqualified fields correctly' do
      models = generate_foo_models
      expected = models.reverse
      FooModel.with_params("order" => "int_field desc").must_equal expected
    end

    it 'orders qualified fields correctly' do
      models = generate_foo_models
      expected = models.reverse
      FooModel.with_params("order" => "foo_models.int_field desc").must_equal expected
    end

    it 'joins has_one relations' do
      models = generate_foo_models
      generate_bar_models
      FooModel.with_params("join" => "bar_model").to_a.must_equal models[0..1]
    end

    it 'joins has_many relations' do
      models = generate_foo_models
      generate_baz_models
      FooModel.with_params("join" => "baz_models").to_a.must_equal [models[0], models[0], models[1], models[1]]
    end

    it 'joins has_many relations and uses field and group' do
      models = generate_foo_models
      generate_baz_models
      expected = [
        {"int_field"=>1, "string_field"=>"onepointone"},
        {"int_field"=>1, "string_field"=>"onepointzero"},
        {"int_field"=>0, "string_field"=>"zeropointone"},
        {"int_field"=>0, "string_field"=>"zeropointzero"},
      ]
      ## TODO: sqlite3 && activerecord-4.0 insert an id field... why!?
      expected.map! do |e|
        e["id"] = nil
        e
      end if ActiveRecord::VERSION::MAJOR >= 4
      query = BazModel.with_params("join" => "foo_model", 
                                   "field" => ["foo_models.int_field", "baz_models.string_field"], 
                                   "group" => ["baz_models.string_field"],
                                   "order" => ["baz_models.string_field"])
      query.collect(&:attributes).must_equal expected
    end

  end

  describe "#httpsql_quote_value" do
    it "quotes absolute names" do
      FooModel.send(:httpsql_quote_value, "foo.bar").must_equal "\"foo\".\"bar\""
    end

    it "converts column names to arel nodes" do
      FooModel.send(:httpsql_quote_value, "int_field").must_be_kind_of Arel::Attributes::Attribute
    end
  end

  describe "#httpsql_quote_value_with_args" do
    it "quotes absolute names" do
      FooModel.send(:httpsql_quote_value, "foo.bar").must_equal "\"foo\".\"bar\""
    end

    it "quotes absolute names with args" do
      FooModel.send(:httpsql_quote_value_with_args, "foo.bar baz").must_equal "\"foo\".\"bar\" baz"
    end
  end

  describe '#httpsql_sql_type_conversion' do
    it 'identifies bigint as Bignum' do
      FooModel.send(:httpsql_sql_type_conversion, 'bigint').must_equal Bignum
    end

    it 'identifies date as Date' do
      FooModel.send(:httpsql_sql_type_conversion, 'date').must_equal Date
    end

    it 'identifies datetime as Time' do
      FooModel.send(:httpsql_sql_type_conversion, 'datetime').must_equal Time
    end

    it 'identifies float as Float' do
      FooModel.send(:httpsql_sql_type_conversion, 'float').must_equal Float
    end

    it 'identifies decimal as Bignum' do
      FooModel.send(:httpsql_sql_type_conversion, 'decimal').must_equal Float
    end

    it 'identifies integer as Fixnum' do
      FooModel.send(:httpsql_sql_type_conversion, 'integer').must_equal Fixnum
    end

    it 'identifies string as String' do
      FooModel.send(:httpsql_sql_type_conversion, 'string').must_equal String
    end

    it 'identifies text as String' do
      FooModel.send(:httpsql_sql_type_conversion, 'text').must_equal String
    end

    it 'identifies character varying(255) as String' do
      FooModel.send(:httpsql_sql_type_conversion, 'character varying(255)').must_equal String
    end

    it 'identifies something as nil' do
      FooModel.send(:httpsql_sql_type_conversion, 'something').must_be_nil
    end
  end

  describe '#grape_documentation' do
    it 'generates the correct documentation for version 0.5.x' do
      TestApi.routes.first.route_params.must_equal({
        "id"           => {:required => false, :type => "Fixnum"},
        "int_field"    => {:required => false, :type => "Fixnum"},
        "dec_field"    => {:required => false, :type => "Float"},
        "string_field" => {:required => false, :type => "String"},
        "access_token" => {:required => false, :type => "String"},
        "created_at"   => {:required => false, :type => "String"},
        "updated_at"   => {:required => false, :type => "String"},
        "field"        => {:required => false, :type => "Array",   :desc => "An array of strings: fields to select from the database"},
        "group"        => {:required => false, :type => "Array",   :desc => "An array of strings: fields to group by"},
        "order"        => {:required => false, :type => "Array",   :desc => "An array of strings: fields to order by"},
        "join"         => {:required => false, :type => "Array",   :desc => "An array of strings: tables to join (bar_model,baz_models)"}

      })
    end

  end

end
