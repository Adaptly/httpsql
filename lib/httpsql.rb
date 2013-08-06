require "httpsql/version"

module Httpsql
  def self.included(base)
    base.send :extend, ClassMethods
  end

  module ClassMethods
    # The method to call within API end points
    # @param params [Hash] The params hash for a given API request
    # @return [ActiveRecord::Relation]
    # @example Constraining a model index end point
    #   resource :my_models
    #     get '/' do
    #       MyModel.with_params(params)
    #     end
    #   end
    # @raise [ActiveRecord::StatementInvalid] if any fields or functions are invalid
    # @raise [ActiveRecord::ConfigurationError] if a join relation is invalid
    def with_params(params={})
      @httpsql_params = params
      @httpsql_conds  = []

      @httpsql_fields = httpsql_extract_fields
      joins  = httpsql_extract_joins
      groups = httpsql_extract_groups
      orders = httpsql_extract_orders

      httpsql_valid_params.each do |k,v|
        k, m = k.to_s.split('.')
        next if k.to_s == 'access_token' 

        # column.sum, column.function=arg1, column.predicate=x
        if m
          httpsql_extract_method(k, m, v)

        # column[]=1&column[]=2 or column=x
        else
          httpsql_extract_default_predicates(k, v)
        end

      end

      @httpsql_conds = @httpsql_conds.inject{|x,y| x.and(y)}

      ar_rel = where(@httpsql_conds)
      ar_rel = ar_rel.select(@httpsql_fields) if @httpsql_fields.any?
      ar_rel = ar_rel.joins(joins)  if joins.any?
      ar_rel = ar_rel.group(groups) if groups.any?
      ar_rel = ar_rel.order(orders) if orders.any?
      ar_rel
    end

    # Provide documentation for Grape end points
    # @param ctx [Object] The calling object
    # @return [Hash]
    # @example Including documentation
    #   params do
    #     MyModel.grape_documentation(self)
    #   end
    def grape_documentation(ctx=nil)
      columns.each do |c|
        opt_hash = {}
        if (k = httpsql_sql_type_conversion(c.type))
          opt_hash[:desc] = k.to_s
        end
        ctx.optional c.name, opt_hash
      end
      ctx.optional :field, desc: "An array of strings: fields to select from the database"
      ctx.optional :group, desc: "An array of strings: fields to group by"
      ctx.optional :order, desc: "An array of strings: fields to order by"
      ctx.optional :join,  desc: "An array of strings: tables to join (#{httpsql_join_tables.join(',')})"
    end

    private
    def httpsql_valid_params
      @httpsql_params.select{|k,v| column_names.include?(k.to_s.split('.').first)}
    end

    def httpsql_quote_value(v)
      v['.'].nil? ? arel_table[v] : v.split('.').map!{|x| connection.quote_table_name(x)}.join('.')
    end

    def httpsql_quote_value_with_args(v, default=nil)
      v = v[' '].nil? ? "#{v} #{default}" : v
      match = v.match(/([^\s]+)(?:\s+(.*))?/)
      q = httpsql_quote_value(match[1])
      if match[2]
        if q.kind_of?(String)
          q + " " + match[2]
        else
          q.send(match[2])
        end
      end
    end

    def httpsql_sql_type_conversion(type)
      type = ':nil' if type.nil?
      case type.to_sym
        when :bigint then Bignum
        when :date then Date
        when :datetime then Time
        when :float, :decimal then Float
        when :integer then Fixnum
        when :string, /text/, /^char/, /^varchar/ then String
        else nil
      end
    end

    def httpsql_join_tables
      @join_tables ||= reflections.keys
    end

    def httpsql_fetch_param(key)
      key_s = key.to_s
      key_sym = key.to_sym
      Array(@httpsql_params[key_sym] || @httpsql_params[key_s])
    end

    def httpsql_extract_fields
      httpsql_fetch_param(:field).map! do |w|
        httpsql_quote_value(w)
      end
    end

    def httpsql_extract_joins
      httpsql_fetch_param(:join).map!(&:to_sym)
    end

    def httpsql_extract_groups
      httpsql_fetch_param(:group).map! do |w|
        httpsql_quote_value(w)
      end
    end

    def httpsql_extract_orders
      httpsql_fetch_param(:order).map! do |w|
        httpsql_quote_value_with_args(w,'asc')
      end
    end

    def httpsql_extract_method(key, method, value)
      # column.sum, column.minimum, column.maximum
      if %w(sum minimum maximum).include?(method)
        @httpsql_fields << arel_table[key].send(method).as(key)
      # column.function=arg1,arg2
      elsif !arel_table[key].respond_to?(method)
        args = value.split(',')
        args.map! do |v| 
          case
            when v =~ /^\d+\.\d+$/ then v.to_f
            when v =~ /^\d+$/ then v.to_i
            else v
          end
        end
        @httpsql_fields << Arel::Nodes::NamedFunction.new(method, [arel_table[key], *args], key)
      # column.arel_predicate (ie lt, gt, not_eq, etc)
      else
        Array(value).each do |v|
          @httpsql_conds << arel_table[key].send(method, v)
        end
      end
    end

    def httpsql_extract_default_predicates(key, value)
      # column[]=1&column[]=2
      if value.respond_to?(:any?)
        @httpsql_conds << arel_table[key].in(value)

      # column=1
      else
        @httpsql_conds << arel_table[key].eq(value)
      end
    end

  end
end

