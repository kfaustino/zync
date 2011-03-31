module Zync
  module Routing
    class Mapper

      class Mapping

        IGNORE_OPTIONS = [:to, :via]

        def initialize(set, path, scope={}, options)
          @set = set
          @scope = scope
          @options = options
          @path = normalize_path(path)
          normalize_options!
        end

        def to_route
          [ app, conditions, defaults ]
        end

        def conditions
          { :path_info => @path , :request_method => request_method}
        end

        private

          def app
            Routing::RouteSet::Dispatcher.new
          end

          def normalize_path(path)
            raise ArgumentError, "path is required" if path.blank?
            path = Mapper.normalize_path(scoped_path(path))
            "#{path}(.:format)"
          end

          def normalize_options!
            @options.merge!(default_controller_and_action)
          end

          def defaults
            @defaults ||= (@options[:defaults] || {}).tap do |defaults|
              @options.each { |k, v| defaults[k] = v unless v.is_a?(Regexp) || IGNORE_OPTIONS.include?(k) }
            end
          end

          def default_controller_and_action
            if to.is_a?(String)
              controller, action = to.split('#')
            elsif to.is_a?(Symbol)
              action = to.to_s
            end

            controller ||= @options[:controller]
            action     ||= @options[:action]

            if controller.is_a?(String) && controller =~ %r{\A/}
              raise ArgumentError, "controller name should not start with a slash"
            end

            controller = controller.to_s unless controller.is_a?(Regexp)
            action     = action.to_s     unless action.is_a?(Regexp)

            raise ArgumentError, "missing :controller" if controller.blank? && segment_keys.exclude?("controller")
            raise ArgumentError, "missing :action" if action.blank?  && segment_keys.exclude?("action")

            { :controller => controller, :action => action }.tap do |hash|
              hash.delete(:controller) if hash[:controller].blank?
              hash.delete(:action)     if hash[:action].blank?
            end
          end

          def request_method
            if(@options[:via])
              @options[:via].to_s.upcase
            else
              'GET'
            end
          end

          def scoped_path(path)
            scoped_paths = @scope[:scoped_path] || []
            scoped_path = scoped_paths.join('')
            "#{scoped_path}#{path}"
          end

          def segment_keys
            @segment_keys ||= Rack::Mount::RegexpWithNamedGroups.new(
              Rack::Mount::Strexp.compile(@path, {}, SEPARATORS)
            ).names
          end

          def to
            @options[:to]
          end

      end

      def self.normalize_path(path)
        Rack::Mount::Utils.normalize_path(path)
      end

      module Base

        # @private
        def initialize(set)
          @set = set
        end

        def match(path, options={})
          mapping = Mapping.new(@set, path, @scope, options || {}).to_route
          @set.add_route(*mapping)
          self
        end

        def get(*args)
          match_method(:get, *args)
          self
        end
        
        def post(*args)
          match_method(:post, *args)
          self
        end
        
        def put(*args)
          match_method(:put, *args)
          self
        end
        
        def delete(*args)
          match_method(:delete, *args)
          self
        end

        private

          def match_method(type, *args)
            options = args.extract_options!
            options[:via] = type
            args.push(options)
            match(*args)
          end

      end

      module Scoping

        def initialize(*args)
          @scope = {}
          super
        end

        def scope(scoped_path, &block)
          with_scope(scoped_path) do
            block.call
          end
        end

        private

          def with_scope(scope)
            @scope[:scoped_path] ||= []
            @scope[:scoped_path] << scope
            yield
            @scope[:scoped_path].pop
          end

      end

      module Resources

        class Resource

          attr_reader :name, :options, :parent_resource, :scope

          def initialize(mapper, name, options={}, parent_resource = nil)
            @mapper = mapper
            @name = name.to_s
            @parent_resource = parent_resource
            @scope = {}
            @options = options.merge!(:controller => @name)
            yield self
          end

          def collection(&block)
            with_scope :collection do
              block.call
            end
          end

          def member(&block)
            with_scope :member do
              block.call
            end
          end

          def resources(*args, &block)
            options = args.extract_options!
            args.push(options)
            Resource.new(@mapper, args.shift.to_s, options, self) do |resource|
              resource.instance_exec(&block) if block_given?

              path = self.class.resource_path(resource)
              @mapper.get path, {:to => :index}.merge!(resource.options)
              @mapper.get "#{path}/:id", {:to => :show}.merge!(resource.options)
            end
          end

          def get(*args)
            options = args.extract_options!
            action_name = args.pop
            resource_path = self.class.resource_path(self)
            path = @scope[:type] == :collection ? "#{resource_path}/#{action_name}" : "#{resource_path}/:id/#{action_name}"
            @mapper.get path, options.merge(:to => action_name.to_sym).merge(self.options)
          end

          def post(*args)
            options = args.extract_options!
            action_name = args.pop
            resource_path = self.class.resource_path(self)
            path = @scope[:type] == :collection ? "#{resource_path}/#{action_name}" : "#{resource_path}/:id/#{action_name}"
            @mapper.post path, options.merge(:to => action_name.to_sym).merge(self.options)
          end

          def match(*args)
            options = args.extract_options!
            match_path = args.pop

            resource_path = self.class.resource_path(self)
            path = @scope[:type] == :member ? "#{resource_path}/:id#{match_path}" : "#{resource_path}#{match_path}"

            @mapper.match path, options.merge(self.options)
          end

          class << self

            def singular_resource_name(name)
              name.chop
            end

            def resource_path(resource)
              parent = resource.parent_resource
              path = ["/#{resource.name}"]
              until parent.nil?
                path.insert(0, "/#{parent.name}/:#{singular_resource_name(parent.name)}_id")
                parent = parent.parent_resource
              end
              path.join('')
            end

          end

          private

            def with_scope(type)
              @scope[:type] = type
              yield
            ensure
              @scope[:type] = nil
            end

        end

        def resources(*args, &block)
          options = args.extract_options!
          args.push(options)
          resource_name = args.shift.to_s

          Resource.new(self, resource_name, options) do |resource|
            resource.instance_exec(&block) if block_given?

            get "/#{resource.name}", {:to => :index}.merge!(resource.options)
            get "/#{resource.name}/:id", {:to => :show}.merge!(resource.options)

          end
          self
        end

      end

      include Base
      include Scoping
      include Resources

    end
  end
end
