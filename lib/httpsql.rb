require "httpsql/version"

module Httpsql
  extend ActiveSupport::Concern
  included do
    class << self
      def valid_params(params)
        params.select{|k,v| column_names.include?(k.to_s.split('.').first)}
      end

      def where_params_eq(params={})

        cond = valid_params(params).map do |k,v|
          next if k.to_s == 'access_token' 
          (k, m) = k.to_s.split('.')
          if m
            arel_table[k.to_sym].send(m.to_sym, v)
          elsif v.respond_to?(:any?)
            arel_table[k.to_sym].in(v)
          else
            arel_table[k.to_sym].eq(v)
          end
        end.inject{|x,y| x.and(y)}

        where(cond)
      end

      def route_params
        columns.inject({}) do |m,c| 
          m[c.name] = {
            type: c.sql_type,
            desc: c.name,
            primary: c.primary
          }
          m
        end
      end


    end
  end
end
