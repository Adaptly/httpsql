require "httpsql/version"

module Httpsql
  def self.included(base)
    base.send :extend, ClassMethods
  end

  module ClassMethods
    def where_params_eq(params={})
      cond = valid_params(params).map do |k,v|
        (k, m) = k.to_s.split('.')
        next if k.to_s == 'access_token' 
        if m
          arel_table[k.to_sym].send(m.to_sym, v)
        elsif v.respond_to?(:any?)
          arel_table[k.to_sym].in(v)
        else
          arel_table[k.to_sym].eq(v)
        end
      end.inject{|x,y| x.and(y)}

      ar_rel = where(cond)
      ar_rel = ar_rel.select(params[:field]) if params[:field]
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
