require 'test_helper'

describe TestApi do
  include ApiHelpers
  include ModelHelpers

  before :all do
    Timecop.freeze
  end

  after :all do
    Timecop.return
  end

  before :each do
    clean_models
  end

  describe "GET /api/v1/foo_models" do
    it "returns an empty array" do
      get "/api/v1/foo_models"
      last_response.body.must_equal "[]"
    end

    it "returns all foo_models" do
      models = generate_foo_models
      get "/api/v1/foo_models"
      last_response.body.must_equal models.to_json
    end

  end

  describe "GET /api/v1/foo_models using eq" do
    it "returns a foo_model eq 1" do
      models = generate_foo_models
      get "/api/v1/foo_models?id=1"
      last_response.body.must_equal [models[0]].to_json
    end

    it "returns a subset of foo_models" do
      models = generate_foo_models
      get "/api/v1/foo_models?id[]=1&id[]=2"
      last_response.body.must_equal models[0..1].to_json
    end

    it "returns all foo_models, if query param is not a column" do
      models = generate_foo_models
      get "/api/v1/foo_models?foo=bar"
      last_response.body.must_equal models.to_json
    end

  end

  describe "GET /api/v1/foo_models using arel" do
    it "returns all foo_models, if query param is not a column" do
      models = generate_foo_models
      get "/api/v1/foo_models?foo.not_eq=bar"
      last_response.body.must_equal models.to_json
    end

    it "returns foo_models not_eq 1" do
      models = generate_foo_models
      get "/api/v1/foo_models?id.not_eq=1"
      last_response.body.must_equal models[1..-1].to_json
    end

    it "returns a subset of foo_models not_eq 1,2" do
      models = generate_foo_models
      get "/api/v1/foo_models?id.not_eq[]=1&id.not_eq[]=2"
      last_response.body.must_equal models[2..-1].to_json
    end

    it "raises ActiveRecord::StatementInvalid for non-existant functions" do
      proc {
        get "/api/v1/foo_models?id.foo[]=1"
      }.must_raise ActiveRecord::StatementInvalid
    end

    it "returns foo_models sum int_field" do
      models = generate_foo_models
      expected = [{int_field: models.collect(&:int_field).sum}]
      ## TODO: sqlite3 && activerecord-4.0 insert an id field... why!?
      expected.first[:id] = nil if ActiveRecord::VERSION::MAJOR >= 4 
      get "/api/v1/foo_models?int_field.sum"
      last_response.body.must_equal expected.to_json
    end

    it "returns foo_models maximum int_field" do
      models = generate_foo_models
      expected = [{int_field: models.collect(&:int_field).max}]
      ## TODO: sqlite3 && activerecord-4.0 insert an id field... why!?
      expected.first[:id] = nil if ActiveRecord::VERSION::MAJOR >= 4 
      get "/api/v1/foo_models?int_field.maximum"
      last_response.body.must_equal expected.to_json
    end

    it "returns foo_models minimum int_field" do
      models = generate_foo_models
      expected = [{int_field: models.collect(&:int_field).min}]
      ## TODO: sqlite3 && activerecord-4.0 insert an id field... why!?
      expected.first[:id] = nil if ActiveRecord::VERSION::MAJOR >= 4 
      get "/api/v1/foo_models?int_field.minimum"
      last_response.body.must_equal expected.to_json
    end

    it "returns foo_models round(dec_field, 1)" do
      models = generate_foo_models
      expected = models.map{|m| {dec_field: m.dec_field.round.to_f.to_s}}
      ## TODO: sqlite3 && activerecord-4.0 insert an id field... why!?
      expected.map! do |e|
        e[:id] = nil 
        e
      end if ActiveRecord::VERSION::MAJOR >= 4 
      get "/api/v1/foo_models?dec_field.round=1"
      last_response.body.must_equal expected.to_json
    end

  end

  describe "GET /api/v1/foo_models?field=" do
    it "raises ActiveRecord::StatementInvalid if the field does not exist" do
      proc {
        get "/api/v1/foo_models?field=foo"
      }.must_raise ActiveRecord::StatementInvalid
    end

    it "returns foo_models id" do
      models = generate_foo_models
      get "/api/v1/foo_models?field=id"
      last_response.body.must_equal models.map{|m| {id: m.id}}.to_json
    end

    it "returns foo_models id,int_field" do
      models = generate_foo_models
      expected = models.
        map{|m| {id: m.id, int_field: m.int_field}}.
        to_json
      get "/api/v1/foo_models?field[]=id&field[]=int_field"
      last_response.body.must_equal expected
    end

    it "returns foo_models foo_models.id" do
      models = generate_foo_models
      get "/api/v1/foo_models?field=foo_models.id"
      last_response.body.must_equal models.map{|m| {id: m.id}}.to_json
    end

    it "returns foo_model foo_models.id,foo_models.int_field" do
      models = generate_foo_models
      expected = models.
        map{|m| {id: m.id, int_field: m.int_field}}.
        to_json
      get "/api/v1/foo_models?field[]=foo_models.id&field[]=foo_models.int_field"
      last_response.body.must_equal expected
    end

    it "returns foo_model id,int_field id=1" do
      models = generate_foo_models
      expected = models.
        select{|m| m.id==1}.
        map{|m| {id: m.id, int_field: m.int_field}}.
        to_json
      get "/api/v1/foo_models?field[]=id&field[]=int_field&id=1"
      last_response.body.must_equal expected
    end

  end

  describe "GET /api/v1/foo_models?group=" do
    it "raises ActiveRecord::StatementInvalid if the group field does not exist" do
      proc {
        get "/api/v1/foo_models?group=foo"
      }.must_raise ActiveRecord::StatementInvalid
    end

    it "returns foo_models grouped by int_field" do
      models = generate_foo_models
      FooModel.create({int_field: 1000})
      model = FooModel.create({int_field: 1000})
      expected = [*models.to_a, model].map! do |m|
        {int_field: m.int_field}
      end
      get "/api/v1/foo_models?group=int_field&field[]=int_field"
      JSON.parse(last_response.body).must_equal expected
    end

    it "returns foo_models grouped by int_field,dec_field" do
      models = generate_foo_models
      FooModel.create({int_field: 1000, dec_field: 1000.0})
      model = FooModel.create({int_field: 1000, dec_field: 1000.0})
      expected = [*models.to_a, model].map! do |m|
        {dec_field: m.dec_field, int_field: m.int_field}
      end
      get "/api/v1/foo_models?group[]=dec_field&group[]=int_field&field[]=dec_field&field[]=int_field"
      JSON.parse(last_response.body).must_equal expected
    end

    it "returns a foo_model foo_models.int_field" do
      models = generate_foo_models
      FooModel.create({int_field: 1000})
      model = FooModel.create({int_field: 1000})
      expected = [*models.to_a, model].map! do |m|
        {int_field: m.int_field}
      end
      get "/api/v1/foo_models?group=foo_models.int_field&field[]=int_field"
      JSON.parse(last_response.body).must_equal expected
    end

    it "returns foo_model foo_models.dec_field,foo_models.int_field" do
      models = generate_foo_models
      FooModel.create({int_field: 1000, dec_field: 1000.0})
      model = FooModel.create({int_field: 1000, dec_field: 1000.0})
      expected = [models.first, model].map! do |m|
        {dec_field: m.dec_field, int_field: m.int_field}
      end
      get "/api/v1/foo_models?group[]=foo_models.dec_field&group[]=foo_models.int_field&field[]=foo_models.dec_field&field[]=foo_models.int_field"
      JSON.parse(last_response.body).must_equal expected
    end

    it "returns foo_model dec_field,int_field id=1,7" do
      models = generate_foo_models
      FooModel.create({int_field: 1000, dec_field: 1000.0})
      model = FooModel.create({int_field: 1000, dec_field: 1000.0})
      expected = [models.first, model].map! do |m|
        {dec_field: m.dec_field, int_field: m.int_field}
      end
      get "/api/v1/foo_models?group[]=dec_field&group[]=int_field&id[]=#{model.id}&id[]=1&field[]=dec_field&field[]=int_field"
      last_response.body.must_equal expected.to_json
    end

  end

  describe "GET /api/v1/foo_models?order=" do
    it "raises ActiveRecord::StatementInvalid if the order field does not exist" do
      proc {
        get "/api/v1/foo_models?order=foo"
      }.must_raise ActiveRecord::StatementInvalid
    end

    it "returns foo_models ordered by dec_field" do
      models = generate_foo_models
      model1 = FooModel.create({dec_field: 1000.2})
      model2 = FooModel.create({dec_field: 1000.1})
      expected = models.to_a << model2 << model1
      get "/api/v1/foo_models?order=dec_field"
      last_response.body.must_equal expected.to_json
    end

    it "returns foo_models ordered by int_field,dec_field" do
      models = generate_foo_models
      model1 = FooModel.create({dec_field: 1000.1, int_field: 10})
      model2 = FooModel.create({dec_field: 1000.1, int_field: 9})
      expected = models.to_a << model2 << model1
      get "/api/v1/foo_models?order[]=dec_field&order[]=int_field"
      last_response.body.must_equal expected.to_json
    end

    it "returns foo_models ordered by foo_models.dec_field" do
      models = generate_foo_models
      model1 = FooModel.create({dec_field: 1000.2})
      model2 = FooModel.create({dec_field: 1000.1})
      expected = models.to_a << model2 << model1
      get "/api/v1/foo_models?order=foo_models.dec_field"
      last_response.body.must_equal expected.to_json
    end

    it "returns foo_models ordered by foo_models.int_field,foo_models.dec_field" do
      models = generate_foo_models
      model1 = FooModel.create({dec_field: 1000.1, int_field: 10})
      model2 = FooModel.create({dec_field: 1000.1, int_field: 9})
      expected = models.to_a << model2 << model1
      get "/api/v1/foo_models?order[]=foo_models.dec_field&order[]=foo_models.int_field"
      last_response.body.must_equal expected.to_json
    end

    it "returns foo_models ordered by dec_field asc" do
      models = generate_foo_models
      model1 = FooModel.create({dec_field: 1000.2})
      model2 = FooModel.create({dec_field: 1000.1})
      expected = models.to_a << model2 << model1
      get "/api/v1/foo_models?order=dec_field+asc"
      last_response.body.must_equal expected.to_json
    end

    it "returns foo_models ordered by int_field asc,dec_field asc" do
      models = generate_foo_models
      model1 = FooModel.create({dec_field: 1000.1, int_field: 10})
      model2 = FooModel.create({dec_field: 1000.1, int_field: 9})
      expected = models.to_a << model2 << model1
      get "/api/v1/foo_models?order[]=dec_field+asc&order[]=int_field+asc"
      last_response.body.must_equal expected.to_json
    end

    it "returns foo_models ordered by foo_models.dec_field asc" do
      models = generate_foo_models
      model1 = FooModel.create({dec_field: 1000.2})
      model2 = FooModel.create({dec_field: 1000.1})
      expected = models.to_a << model2 << model1
      get "/api/v1/foo_models?order=foo_models.dec_field+asc"
      last_response.body.must_equal expected.to_json
    end

    it "returns foo_models ordered by foo_models.int_field asc,foo_models.dec_field asc" do
      models = generate_foo_models
      model1 = FooModel.create({dec_field: 1000.1, int_field: 10})
      model2 = FooModel.create({dec_field: 1000.1, int_field: 9})
      expected = models.to_a << model2 << model1
      get "/api/v1/foo_models?order[]=foo_models.dec_field+asc&order[]=foo_models.int_field+asc"
      last_response.body.must_equal expected.to_json
    end

    it "returns foo_models ordered by foo_models.int_field desc,foo_models.dec_field asc" do
      models = generate_foo_models
      model1 = FooModel.create({dec_field: 1000.1, int_field: 10})
      model2 = FooModel.create({dec_field: 1000.1, int_field: 9})
      expected = models.to_a << model1 << model2
      get "/api/v1/foo_models?order[]=foo_models.dec_field+asc&order[]=foo_models.int_field+desc"
      last_response.body.must_equal expected.to_json
    end

    it "returns foo_models ordered by dec_field desc" do
      models = generate_foo_models
      model1 = FooModel.create({dec_field: 1000.2})
      model2 = FooModel.create({dec_field: 1000.1})
      expected = models.to_a << model2 << model1
      get "/api/v1/foo_models?order=dec_field+desc"
      last_response.body.must_equal expected.reverse.to_json
    end

    it "returns foo_models ordered by int_field desc,dec_field desc" do
      models = generate_foo_models
      model1 = FooModel.create({dec_field: 1000.1, int_field: 10})
      model2 = FooModel.create({dec_field: 1000.1, int_field: 9})
      expected = models.to_a << model2 << model1
      get "/api/v1/foo_models?order[]=dec_field+desc&order[]=int_field+desc"
      last_response.body.must_equal expected.reverse.to_json
    end

    it "returns foo_models ordered by foo_models.dec_field desc" do
      models = generate_foo_models
      model1 = FooModel.create({dec_field: 1000.2})
      model2 = FooModel.create({dec_field: 1000.1})
      expected = models.to_a << model2 << model1
      get "/api/v1/foo_models?order=foo_models.dec_field+desc"
      last_response.body.must_equal expected.reverse.to_json
    end

    it "returns foo_models ordered by foo_models.int_field desc,foo_models.dec_field desc" do
      models = generate_foo_models
      model1 = FooModel.create({dec_field: 1000.1, int_field: 10})
      model2 = FooModel.create({dec_field: 1000.1, int_field: 9})
      expected = models.to_a << model2 << model1
      get "/api/v1/foo_models?order[]=foo_models.dec_field+desc&order[]=foo_models.int_field+desc"
      last_response.body.must_equal expected.reverse.to_json
    end

  end

  describe "GET /api/v1/foo_models?join= (has_one)" do
    it "raises ActiveRecord::ConfigurationError if the join field does not exist" do
      proc {
        get "/api/v1/foo_models?join=foo"
      }.must_raise ActiveRecord::ConfigurationError
    end

    it "returns empty array (foo_models without bar_models)" do
      foo_models = generate_foo_models
      get "/api/v1/foo_models?join=bar_model"
      last_response.body.must_equal "[]"
    end

    it "returns foo_models (foo_models with bar_models)" do
      foo_models = generate_foo_models
      bar_models = generate_bar_models
      get "/api/v1/foo_models?join=bar_model"
      last_response.body.must_equal foo_models[0..1].to_json
    end

  end

  describe "GET /api/v1/baz_models?join= (belongs_to)" do
    it "returns empty array (baz_models without foo_models)" do
      baz_models = generate_baz_models
      get "/api/v1/baz_models?join=foo_model"
      last_response.body.must_equal "[]"
    end

    it "returns baz_models (baz_models with foo_models)" do
      baz_models = generate_baz_models
      foo_models = generate_foo_models
      get "/api/v1/baz_models?join=foo_model"
      last_response.body.must_equal baz_models.to_json
    end

  end

  describe "GET /api/v1/baz_models?join=&field=&order=" do
    it "returns the expected object" do
      baz_models = generate_baz_models
      foo_models = generate_foo_models
      # TODO: fucking travis, AR < 4 orders fields differently...
      expected = baz_models.map do |m|
        {"id" => m.id, "foo_model_id" => m.foo_model_id, "int_field" => m.foo_model.int_field}
      end
      get "/api/v1/baz_models?join=foo_model&field[]=id&field[]=foo_model_id&field[]=foo_models.int_field&order=foo_models.int_field"
      JSON.parse(last_response.body).must_equal expected
    end

    it "returns the expected object for gt" do
      baz_models = generate_baz_models
      foo_models = generate_foo_models
      # TODO: fucking travis, AR < 4 orders fields differently...
      expected = baz_models.select{|m| m.foo_model_id>1}.map! do |m|
        {"id" => m.id, "foo_model_id" => m.foo_model_id, "int_field" => m.foo_model.int_field}
      end
      get "/api/v1/baz_models?join=foo_model&field[]=id&field[]=foo_model_id&field[]=foo_models.int_field&order=foo_models.int_field&foo_model_id.gteq=2"
      JSON.parse(last_response.body).must_equal expected
    end

    it "returns the expected object for sum" do
      baz_models = generate_baz_models
      foo_models = generate_foo_models
      # TODO: fucking travis, AR < 4 orders fields differently...
      expected = baz_models[1..2].map do |m|
        {"id" => m.foo_model_id*2, "foo_model_id" => m.foo_model_id*2, "int_field" => m.foo_model.int_field}
      end
      get "/api/v1/baz_models?join=foo_model&field[]=foo_model_id&field[]=foo_models.int_field&field[]=foo_models.dec_field"
      JSON.parse(last_response.body).must_equal expected.reverse
    end

  end

end
