require 'active_support/all'
require 'active_model'

module MiniForm
  module Model
    def self.included(base) # rubocop:disable MethodLength
      base.class_eval do
        include ActiveModel::Validations
        include ActiveModel::Validations::Callbacks
        include ActiveModel::Conversion

        extend ActiveModel::Naming
        extend ActiveModel::Callbacks

        extend ClassMethods

        define_model_callbacks :update
        define_model_callbacks :assigment

        before_update :before_update
        after_update :after_update

        before_assigment :before_assigment
        after_assigment :after_assigment
      end
    end

    def initialize(attributes = {})
      self.attributes = attributes
    end

    def persisted?
      false
    end

    def attributes=(attributes)
      run_callbacks :assigment do
        attributes.slice(*self.class.attribute_names).each do |name, value|
          public_send "#{name}=", value
        end
      end
    end

    alias_method :assign_attributes, :attributes=

    def attributes
      Hash[self.class.attribute_names.map { |name| [name, public_send(name)] }]
    end

    def update(attributes = {})
      self.attributes = attributes unless attributes.empty?

      return false unless valid?

      run_callbacks :update do
        transaction do
          save_models
          perform
        end
      end

      true
    end

    def update!(attributes = {})
      fail InvalidForm, self unless update attributes
      self
    end

    private

    def transaction(&block)
      if defined? ActiveRecord
        ActiveRecord::Base.transaction(&block)
      else
        yield
      end
    end

    # :api: private
    def save_models
      self.class.models_to_save.each { |model_name| public_send(model_name).save! }
    end

    def perform
      # noop
    end

    def before_update
      # noop
    end

    def after_update
      # noop
    end

    def before_assigment
      # noop
    end

    def after_assigment
      # noop
    end

    module ClassMethods
      def inherited(base)
        new_attribute_names = attribute_names.dup
        new_models_to_save  = models_to_save.dup

        base.instance_eval do
          @attribute_names = new_attribute_names
          @models_to_save  = new_models_to_save
        end
      end

      def attribute_names
        @attribute_names ||= []
      end

      # :api: private
      def models_to_save
        @models_to_save ||= []
      end

      def attributes(*attributes, delegate: nil, prefix: nil, allow_nil: nil)
        attribute_names.push(*attributes)

        if delegate.nil?
          attr_accessor(*attributes)
        else
          delegate(*attributes, to: delegate, prefix: prefix, allow_nil: allow_nil)
          delegate(*attributes.map { |attr| "#{attr}=" }, to: delegate, prefix: prefix, allow_nil: allow_nil)
        end
      end

      def model(name, attributes: [], read: [], prefix: nil, allow_nil: nil, save: false) # rubocop:disable ParameterLists
        attr_accessor name

        attributes(*attributes, delegate: name, prefix: prefix, allow_nil: allow_nil) unless attributes.empty?

        delegate(*read, to: name, prefix: prefix, allow_nil: nil)

        validates name, 'mini_form/nested' => true

        models_to_save << name if save
      end
    end
  end
end
