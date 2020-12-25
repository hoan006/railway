# frozen_string_literal: true

# Include this module to enable Railway syntactic expression.
# Example:
#
# class Lorem
#   include Railway
#
#   def greeting(person)
#     with { person }.as var(:pax).when { pax.is_a? String }
#       .then { "Hello, #{pax}" }.as var(:message) do
#       pp message
#     end.run
#   end
# end
#
module Railway
  def var(sym, setter: nil)
    block = BuildingBlock.new(name: sym, setter_name: setter)
    Builder.new(block)
  end

  def with(&assign_block)
    block = BuildingBlock.new(assign_block: assign_block)
    Builder.new(block, self)
  end

  BuildingBlock = Struct.new(
    :name, :setter_name, :assign_block, :guard_block, :extra_blocks,
    keyword_init: true
  )

  # This class is used to combine and execute building block properly
  #
  class Builder
    attr_reader :blocks

    def initialize(starting_block, ctx = nil)
      @blocks = [starting_block]
      @context = ctx
    end

    def when(&block)
      blocks.first.guard_block = block
      self
    end

    def then(&block)
      blocks.last.extra_blocks = [*blocks.last.extra_blocks, next_assign_block] if next_assign_block

      @next_assign_block = block
      self
    end

    def as(next_builder, &block) # rubocop:disable Metrics/MethodLength
      if block
        @accept_block = block
        assign_block = blocks.first.assign_block
        @blocks = next_builder.blocks.clone
        blocks.first.assign_block = assign_block
      else
        next_blocks = next_builder.blocks.clone
        next_blocks.first.assign_block = next_assign_block
        @blocks += next_blocks
        @next_assign_block = nil
      end
      self
    end

    def otherwise(&block)
      @reject_block = block if block
      self
    end

    def run
      @result = Struct.new(*blocks.map(&:name)).new

      blocks.each do |block|
        apply_block(block)
        return reject(block) unless continue_block?(block)

        [*block.extra_blocks].each { |b| instance_exec(&b) }
      end

      instance_exec(&accept_block)
    end

    private

    attr_reader :context, :next_assign_block, :result, :accept_block, :reject_block

    def apply_block(block)
      sym = block.name
      result[sym] = instance_exec(&block.assign_block)
      return if !context || !block.setter_name

      context.instance_variable_set("@#{block.setter_name}".to_sym, result[sym])
    end

    def continue_block?(block)
      !block.guard_block || instance_exec(&block.guard_block)
    end

    def reject(block)
      sym = block.name
      reject_block && instance_exec(sym, result[sym], &reject_block)
    end

    def method_missing(a_method, *args, &block)
      return result[a_method] if result&.members&.include?(a_method)

      return context.send(a_method, *args, &block) if context.respond_to?(a_method, true)

      super(a_method, *args, &block)
    end

    def respond_to_missing?(a_method, *)
      result&.members&.include?(a_method) || context.respond_to?(a_method)
    end
  end
end
