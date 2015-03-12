require "rails_erd/domain"

module RailsERD
  # This class is an abstract class that will process a domain model and
  # allows easy creation of diagrams. To implement a new diagram type, derive
  # from this class and override +process_entity+, +process_relationship+,
  # and (optionally) +save+.
  #
  # As an example, a diagram class that generates code that can be used with
  # yUML (http://yuml.me) can be as simple as:
  #
  #   require "rails_erd/diagram"
  #
  #   class YumlDiagram < RailsERD::Diagram
  #     setup { @edges = [] }
  #
  #     each_relationship do |relationship|
  #       return if relationship.indirect?
  #
  #       arrow = case
  #       when relationship.one_to_one?   then "1-1>"
  #       when relationship.one_to_many?  then "1-*>"
  #       when relationship.many_to_many? then "*-*>"
  #       end
  #
  #       @edges << "[#{relationship.source}] #{arrow} [#{relationship.destination}]"
  #     end
  #
  #     save { @edges * "\n" }
  #   end
  #
  # Then, to generate the diagram (example based on the domain model of Gemcutter):
  #
  #   YumlDiagram.create
  #   #=> "[Rubygem] 1-*> [Ownership]
  #   #    [Rubygem] 1-*> [Subscription]
  #   #    [Rubygem] 1-*> [Version]
  #   #    [Rubygem] 1-1> [Linkset]
  #   #    [Rubygem] 1-*> [Dependency]
  #   #    [Version] 1-*> [Dependency]
  #   #    [User] 1-*> [Ownership]
  #   #    [User] 1-*> [Subscription]
  #   #    [User] 1-*> [WebHook]"
  #
  # For another example implementation, see Diagram::Graphviz, which is the
  # default (and currently only) diagram type that is used by Rails ERD.
  #
  # === Options
  #
  # The following options are available and will by automatically used by any
  # diagram generator inheriting from this class.
  #
  # attributes:: Selects which attributes to display. Can be any combination of
  #              +:content+, +:primary_keys+, +:foreign_keys+, +:timestamps+, or
  #              +:inheritance+.
  # disconnected:: Set to +false+ to exclude entities that are not connected to other
  #                entities. Defaults to +false+.
  # indirect:: Set to +false+ to exclude relationships that are indirect.
  #            Indirect relationships are defined in Active Record with
  #            <tt>has_many :through</tt> associations.
  # inheritance:: Set to +true+ to include specializations, which correspond to
  #               Rails single table inheritance.
  # polymorphism:: Set to +true+ to include generalizations, which correspond to
  #                Rails polymorphic associations.
  # warn:: When set to +false+, no warnings are printed to the
  #        command line while processing the domain model. Defaults
  #        to +true+.
  class Diagram
    class << self
      # Generates a new domain model based on all <tt>ActiveRecord::Base</tt>
      # subclasses, and creates a new diagram. Use the given options for both
      # the domain generation and the diagram generation.
      def create(options = {})
        new(Domain.generate(options), options).create
      end

      protected

      def setup(&block)
        callbacks[:setup] = block
      end

      def each_entity(&block)
        callbacks[:each_entity] = block
      end

      def each_relationship(&block)
        callbacks[:each_relationship] = block
      end

      def each_specialization(&block)
        callbacks[:each_specialization] = block
      end

      def save(&block)
        callbacks[:save] = block
      end

      private

      def callbacks
        @callbacks ||= Hash.new { proc {} }
      end
    end

    # The options that are used to create this diagram.
    attr_reader :options

    # The domain that this diagram represents.
    attr_reader :domain

    # Create a new diagram based on the given domain.
    def initialize(domain, options = {})
      @domain, @options = domain, RailsERD.options.merge(options)
    end

    # Generates and saves the diagram, returning the result of +save+.
    def create
      generate
      save
    end

    # Generates the diagram, but does not save the output. It is called
    # internally by Diagram#create.
    def generate
      instance_eval &callbacks[:setup]

      filtered_entities.each do |entity|
        instance_exec entity, filtered_attributes(entity), &callbacks[:each_entity]
      end

      filtered_specializations.each do |specialization|
        instance_exec specialization, &callbacks[:each_specialization]
      end

      filtered_relationships.each do |relationship|
        instance_exec relationship, &callbacks[:each_relationship]
      end
    end

    def save
      instance_eval &callbacks[:save]
    end

    private

    def callbacks
      @callbacks ||= self.class.send(:callbacks)
    end

    def filtered_entities
     p "options"
     options.each do |o|
       p o
     end

     main_array = @domain.entities
     # Supporitng "only" option first
     only_options_present = !options.only.nil?

     # Set of the specified objects to draw
     only_options_array = if only_options_present 
                           [options.only].flatten.map(&:to_sym)  
                         end

     # Set of the related objects to draw
     selected_from_only_array = if only_options_present
                        main_array.select do |entity|
                          entity.name && entity_is_related?(entity, only_options_array)
                        end
                       end


     # Supporitng "exclude" option second
     exclude_options_present = !options.exclude.nil?
     exclude_options_array = if exclude_options_present 
                           [options.exclude].flatten.map(&:to_sym)  
                         end
    
     without_excluded_array = if exclude_options_present && only_options_present 
                                    selected_from_only_array.reject do |entity|
                                        entity.name && exclude_options_array.include?(entity.name.to_sym)
                                    end
                              elsif exclude_options_present && !only_options_present
                                    main_array.reject do |entity|
                                        entity.name && exclude_options_array.include?(entity.name.to_sym)
                                    end
                              elsif !exclude_options_present && only_options_present
                                    selected_from_only_array
                              else
                                    main_array
                              end
      
  
     ###################
     #old code
     ###################

     old_array = @domain.entities.reject { |entity|
        options.exclude && entity.model && [options.exclude].flatten.include?(entity.name.to_sym) or
        only_options_present && entity.name  && !only_options_array.include?(entity.name.to_sym) or
        !options.inheritance && entity.specialized? or
        !options.polymorphism && entity.generalized? or
        !options.disconnected && entity.disconnected?
      }.compact.tap do |entities|
        raise "No entities found; create your models first!" if entities.empty?
      end
     ####################
   
 ###########################
    #DEBUG
   
  @domain.relationships_by_entity_name("PayableInvoice").each do |r|
   p " source name = #{r.source.name}, source model = #{r.source.model} destination name = #{r.destination.name} destination model #{r.destination.model}" 
  end

 
  pai = @domain.entity_by_name("PayableInvoice")
  p "specialiezed? #{pai.specialized?}"

  p "@"*10
  @domain.specializations_by_entity_name("PayableInvoice").each do |s|
   p s.specialized.name
   p s.generalized.name
  end
#  require 'pry'; binding.pry
#    p "="*30
#  p "after"
#    new_array.each do |e|
#     p "name= #{e.name} model= #{e.model}"
#  end
# p "="*30
#
 #########################################
  #OUTPUT
  ##########################################
      if !without_excluded_array.nil? 
      p "=============new array"
      without_excluded_array
     else
       old_array
     end
    end
    
    def entity_is_related?(entity, array)
      return true if array.include?(entity.name.to_sym)
      #p "*"*30
      #p "name = #{entity.name}, model = #{ entity.model}, domain =  #{entity.domain.name}"
      
        entity.relationships.each do |r| 
        #p "source = #{r.source.name}, destination = #{r.destination.name}"
         if (array.include?(r.source.name.to_sym) || array.include?(r.destination.name.to_sym))
           #p "*"*30
           #p r.source.name.to_sym
           #p r.destination.name.to_sym
           return true
         end
        end

      @domain.specializations_by_entity_name(entity.name).each do |s|
          #p "name = #{entity.name} generalized #{s.generalized.name} specialized #{s.specialized.name}"
          if (array.include?(s.generalized.name.to_sym) || array.include?(s.specialized.name.to_sym))
            return true
          end
        end
   
     return false
    end

 
#    def filtered_entities
#      @domain.entities.reject { |entity|
#        options.exclude && entity.model && [options.exclude].flatten.include?(entity.name.to_s) or
#        options.only && entity.model && ![options.only].flatten.include?(entity.name.to_s) or
#        !options.inheritance && entity.specialized? or
#        !options.polymorphism && entity.generalized? or
#        !options.disconnected && entity.disconnected?
#      }.compact.tap do |entities|
#        raise "No entities found; create your models first!" if entities.empty?
#      end
#    end

    def filtered_relationships
      @domain.relationships.reject { |relationship|
        !options.indirect && relationship.indirect?
      }
    end

    def filtered_specializations
      @domain.specializations.reject { |specialization|
        !options.inheritance && specialization.inheritance? or
        !options.polymorphism && specialization.polymorphic?
      }
    end

    def filtered_attributes(entity)
      entity.attributes.reject { |attribute|
        # Select attributes that satisfy the conditions in the :attributes option.
        !options.attributes or entity.specialized? or
        [*options.attributes].none? { |type| attribute.send(:"#{type.to_s.chomp('s')}?") }
      }
    end

    def warn(message)
      puts "Warning: #{message}" if options.warn
    end
  end
end
