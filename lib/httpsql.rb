require "httpsql/version"

module Httpsql
  def self.included(base)
    base.send :extend, ClassMethods
  end

  module ClassMethods
    def where_params_eq(params={})
      fields = params[:field] || []
      conds = []

      valid_params(params).each do |k,v|
        (k, m) = k.to_s.split('.')
        next if k.to_s == 'access_token' 
        if m
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
      ar_rel = ar_rel.select(fields) if fields.any?
      ar_rel
    end

    def route_params
      columns.inject({}) do |m,c| 
        m[c.name] = {
          type: c.sql_type,
          desc: c.name,
          primary: c.primary
        }
        m
      end.merge "field" => {
        type: 'array',
        desc: 'select fields',
        primary: false
      }
    end

    private
    def valid_params(params)
      params.select{|k,v| column_names.include?(k.to_s.split('.').first)}
    end
  end
end

