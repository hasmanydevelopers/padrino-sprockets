# encoding: utf-8
require "sprockets"
require "tilt"

module Sprockets
  class JSMinifier < Tilt::Template
    def prepare
    end

    def evaluate(context, locals, &block)
      Uglifier.compile(data, :comments => :none)
    end
  end
end

module Padrino
  module Sprockets
    module Helpers
      module ClassMethods
        def sprockets(options={})
          url   = options[:url] || 'assets'
          _root = options[:root] || root
          paths = options[:paths] || []
          set :sprockets_url, url
          options[:root] = _root
          options[:url] = url
          options[:paths] = paths
          use Padrino::Sprockets::App, options
        end
      end

      module AssetTagHelpers
        # Change the folders to /assets/
        def asset_folder_name(kind)
          case kind
          when :css then 'assets'
          when :js  then 'assets'
          when :images then 'assets'
          else kind.to_s
          end
        end
      end # AssetTagHelpers

      def self.included(base)
        base.send(:include, AssetTagHelpers)
        base.extend ClassMethods
      end
    end #Helpers

    class App
      attr_reader :assets

      def initialize(app, options={})
        @app = app
        @root = options[:root]
        url   =  options[:url] || 'assets'
        @matcher = /^\/#{url}\/*/
        setup_environment(options[:minify], options[:paths] || [])
      end

      def setup_environment(minify=false, extra_paths=[])
        @assets = ::Sprockets::Environment.new(@root)
        @assets.append_path 'assets/javascripts'
        @assets.append_path 'assets/stylesheets'
        @assets.append_path 'assets/images'

        if minify
          if defined?(YUI)
            @assets.css_compressor = YUI::CssCompressor.new
          else
            puts "Add yui-compressor to your Gemfile to enable css compression"
          end
          if defined?(Uglifier)
            @assets.register_postprocessor "application/javascript", ::Sprockets::JSMinifier
          else
            puts "Add uglifier to your Gemfile to enable js minification"
          end
        end

        extra_paths.each do |sprocket_path|
          @assets.append_path sprocket_path
        end

        # put public assets in sprockets path
        %w{images stylesheets javascripts}.each do |dir|
          public_path = File.join(Padrino.root, "public", dir)
          if File.exist?(public_path)
            @assets.append_path File.join(Padrino.root, "public", dir)
          end
        end

        # put bootstrap assets in sprockets path
        if defined?(::Bootstrap)
          %w{fonts stylesheets javascripts}.each do |dir|
            bootstrap_path = File.join(::Bootstrap.assets_path, dir)
            unless extra_paths.include?(bootstrap_path)
              @assets.append_path bootstrap_path
            end
          end

          # this is required to serve bootstrap fonts
          @assets.context_class.class_eval do
            def asset_path(path, options = {})
              path
            end
          end
        end
      end

      def call(env)
        if @matcher =~ env["PATH_INFO"]
          env['PATH_INFO'].sub!(@matcher,'')
          @assets.call(env)
        else
          @app.call(env)
        end
      end
    end

    class << self
      def registered(app)
        app.helpers Padrino::Sprockets::Helpers
      end
    end
  end #Sprockets
end #Padrino
