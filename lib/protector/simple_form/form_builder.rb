module Protector
  module SimpleForm
    module FormBuilder
      extend ActiveSupport::Concern
      
      included do
        alias_method :association_without_monkey_patch, :association
        def association(association, options={}, &block)
          options = options.dup
          
          # Always protect unless otherwise specified.
          options[:protect] = true unless options[:protect] == false
          
          if options[:protect] == true && @object.respond_to?(:protector_subject?) && @object.protector_subject?
            return simple_fields_for(*[association, options.delete(:collection), options].compact, &block) if block_given?
            
            reflection = find_association_reflection(association)
            raise "Association #{association.inspect} not found" unless reflection
            
            options[:collection] ||= options.fetch(:collection) do
              # Protect using the same subject as the the current object.
              reflection.klass.restrict!(@object.protector_subject).where(reflection.options[:conditions]).order(reflection.options[:order]).to_a
            end
          end
          
          association_without_monkey_patch association, options, &block
        end

        alias_method :input_without_monkey_patch, :input
        def input(attribute_name, options={}, &block)
          if @object.respond_to?(:protector_subject?) && @object.protector_subject?
            protector_attribute = options[:protector_attribute] || attribute_name
            if options[:protector_readonly] != false && (
              (@object.persisted? && !@object.can?(:update, protector_attribute)) ||
              (@object.new_record? && !@object.can?(:create, protector_attribute))
              )
              case find_input(attribute_name, options, &block).input_type
              when :select
                options[:disabled] = true unless options[:disabled] == false
              when :check_boxes
                if options[:input_html].present?
                  options[:input_html].merge(onclick: "return false")
                else
                  options[:input_html] = {onclick: "return false"}
                end
                options[:item_wrapper_class] = "#{options[:item_wrapper_class]} readonly"
              else
                options[:readonly] = true unless options[:readonly] == false
              end
            end
          end

          input_without_monkey_patch attribute_name, options, &block
        end
 
      end
    end
  end
end
