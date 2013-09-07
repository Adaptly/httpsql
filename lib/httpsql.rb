require "httpsql/version"

module Httpsql
  MAX_PARAMS = 3

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
      @httpsql_joins  = httpsql_extract_joins
      groups = httpsql_extract_groups
      orders = httpsql_extract_orders

      httpsql_valid_params.each do |key,value|
        table = method = nil
        fields = key.to_s.split('.', MAX_PARAMS)
        if fields.count == MAX_PARAMS
          table, key, method = fields
        else
          table = self.table_name
          key, method = fields
        end
        next if key.to_s == 'access_token' 

        # table.column.sum, table.column.function=arg1, table.column.predicate=x
        # column.sum, column.function=arg1, column.predicate=x
        if method
          httpsql_extract_method(table, key, method, value)

        # column[]=1&column[]=2 or column=x
        else
          httpsql_extract_default_predicates(table, key, value)
        end

      end

      @httpsql_conds = @httpsql_conds.inject{|x,y| x.and(y)}

      ar_rel = where(@httpsql_conds)
      ar_rel = ar_rel.select(@httpsql_fields) if @httpsql_fields.any?
      ar_rel = ar_rel.joins(@httpsql_joins)   if @httpsql_joins.any?
      ar_rel = ar_rel.group(groups)           if groups.any?
      ar_rel = ar_rel.order(orders)           if orders.any?
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

    def httpsql_objectify(table)
      table.to_s.classify.constantize
    end

    def httpsql_arelize(table)
      httpsql_objectify(table).arel_table
    end

    def httpsql_selectable_join_columns
      httpsql_join_tables.map do |join|
        obj = httpsql_objectify(join)
        obj.column_names.map do |col|
          "#{join}.#{col}"
        end
      end.flatten
    end

    def httpsql_selected_join_params
      @httpsql_params.select do |k,v|
        spl = k.to_s.split('.', MAX_PARAMS)
        spl[1] && httpsql_selectable_join_columns.include?("#{spl[0]}.#{spl[1]}")
      end
    end

    def httpsql_selected_params
      @httpsql_params.select do |k,v|
        spl = k.to_s.split('.', MAX_PARAMS)
        column_names.include?(spl.first)
      end
    end

    def httpsql_valid_params
      httpsql_selected_params.merge httpsql_selected_join_params
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

    def httpsql_extract_method(table, key, method, value)
      t = httpsql_arelize(table)
      # table.column.sum, table.column.minimum, table.column.maximum
      # column.sum, column.minimum, column.maximum
      if %w(sum minimum maximum).include?(method)
        @httpsql_fields << t[key].send(method).as(key)
      # column.function=arg1,arg2
      elsif !t[key].respond_to?(method)
        args = value.split(',')
        @httpsql_fields << Arel::Nodes::NamedFunction.new(method, [t[key], *args], key)
      # column.arel_predicate (ie lt, gt, not_eq, etc)
      else
        Array(value).each do |v|
          @httpsql_conds << t[key].send(method, v)
        end
      end
    end

    def httpsql_extract_default_predicates(table, key, value)
      t = httpsql_arelize(table)
      # column[]=1&column[]=2
      if value.respond_to?(:any?)
        @httpsql_conds << t[key].in(value)

      # column=1
      else
        @httpsql_conds << t[key].eq(value)
      end
    end

  end
end

