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
    def with_params(params={})
      fields = []
      conds  = []
      joins  = []
      groups = []
      orders = []

      fields += Array(params[:field] || params['field'])

      httpsql_valid_params(params).each do |k,v|
        k, m = k.to_s.split('.')
        next if k.to_s == 'access_token' 

        if k == 'join'
          joins += Array(v).map!(&:to_sym)
        elsif k == 'order'
          orders += Array(v).map!{|w| httpsql_quote_value_with_args(w)}
        elsif k == 'group'
          groups += Array(v).map!{|w| httpsql_quote_value(w)}
        elsif m
          if %w(sum minimum maximum).include?(m)
            fields << arel_table[k].send(m).as(k)
          elsif !arel_table[k].respond_to?(m)
            args = v.split(',')
            fields << Arel::Nodes::NamedFunction.new(m, [arel_table[k], *args], k)
          else
            conds << arel_table[k].send(m, v)
          end
        elsif v.respond_to?(:any?)
          conds << arel_table[k].in(v)
        else
          conds << arel_table[k].eq(v)
        end
      end

      conds = conds.compact.inject{|x,y| x.and(y)}

      ar_rel = where(conds)
      ar_rel = ar_rel.joins(joins)   if joins.any?
      ar_rel = ar_rel.group(groups)  if groups.any?
      ar_rel = ar_rel.order(orders)  if orders.any?
      ar_rel = ar_rel.select(fields) if fields.any?
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
          opt_hash[:type] = k 
        end
        ctx.optional c.name, opt_hash
      end
      ctx.optional :field, type: Array, desc: "An array of strings: fields to select from the database"
      ctx.optional :group, type: Array, desc: "An array of strings: fields to group by"
      ctx.optional :order, type: Array, desc: "An array of strings: fields to order by"
      ctx.optional :join,  type: Array, desc: "An array of strings: tables to join (#{httpsql_join_tables.join(',')})"
    end

    private
    def httpsql_valid_params(params)
      params.select{|k,v| [*column_names, 'join', 'group', 'order'].include?(k.to_s.split('.').first)}
    end

    def httpsql_quote_value(v)
      v['.'].nil? ? arel_table[v] : v.split('.').map!{|x| connection.quote_table_name(x)}.join('.')
    end

    def httpsql_quote_value_with_args(v)
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

  end
end

