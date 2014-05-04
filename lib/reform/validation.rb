require 'forwardable'
require 'uber/inheritable_attr'

require 'reform/representer'

module Reform
  # Gives you a DSL for defining the object structure and its validations.
  class Validation # DISCUSS: make class?
    extend Forwardable

    extend Uber::InheritableAttr
    inheritable_attr :representer_class
    self.representer_class = Class.new(Reform::Representer)

    inheritable_attr :features
    self.features = []


    module PropertyMethods
      extend Forwardable

      def property(name, options={}, &block)
        options[:private_name] = options.delete(:as)

        # at this point, :extend is a Form class.
        options[:features] = features if block_given?
        definition = representer_class.property(name, options, &block)
        setup_form_definition(definition) if block_given? or options[:form]

        create_accessor(name)
        definition
      end

      def collection(name, options={}, &block)
        options[:collection] = true

        property(name, options, &block)
      end

      def properties(names, *args)
        names.each { |name| property(name, *args) }
      end

      def setup_form_definition(definition)
        options = {
          :form         => definition[:form] || definition[:extend].evaluate(nil), # :form is always just a Form class name.
          :pass_options => true, # new style of passing args
          :prepare      => lambda { |form, args| form }, # always just return the form without decorating.
        }

        definition.merge!(options)
      end

    private
      def create_accessor(name)
        # Make a module that contains these very accessors, then include it
        # so they can be overridden but still are callable with super.
        accessors = Module.new do
          extend Forwardable # DISCUSS: do we really need Forwardable here?
          delegate [name, "#{name}="] => :fields
        end
        include accessors
      end
    end
    extend PropertyMethods


    # FIXME: make AM optional.
    require 'active_model'
    include ActiveModel::Validations


    attr_accessor :model

    require 'reform/validation/setup'
    include Setup


  private
    attr_accessor :fields

    def mapper
      self.class.representer_class
    end


    # Keeps values of the form fields. What's in here is to be displayed in the browser!
    # we need this intermediate object to display both "original values" and new input from the form after submitting.
    class Fields < OpenStruct
      def initialize(properties, values={})
        fields = properties.inject({}) { |hsh, attr| hsh.merge!(attr => nil) }
        super(fields.merge!(values))  # TODO: stringify value keys!
      end
    end # Fields
  end
end