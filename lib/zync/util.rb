module Zync
  module Util
    class << self
      
      # TODO: would be better if activesupport's method was recursive
      # Method from: http://snippets.dzone.com/posts/show/11121
      def symbolize_keys(arg)
        case arg
        when Array
          arg.map { |elem| symbolize_keys elem }
        when Hash
          Hash[
            arg.map { |key, value|  
              k = key.is_a?(String) ? key.to_sym : key
              v = symbolize_keys value
              [k,v]
            }]
        else
          arg
        end
      end
      
    end
  end
end