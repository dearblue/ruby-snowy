require_relative "common"
require "cairo"

module Snowy
  using Extentions

  module CairoDriver
    def self.render(size, triangles, background, color, outline, angle)
      shapes = Aux.build_shape_from_triangle(triangles)
      deg2rad = Math::PI / 180
      sqrt3 = Math.sqrt(3)
      surface = Cairo::ImageSurface.new(Cairo::Format::ARGB32, size, size)
      Cairo::Context.new(surface) do |context|
        context.instance_eval do
          set_source_color [background.get_red / 255.0, background.get_green / 255.0, background.get_blue / 255.0, background.get_alpha / 255.0]
          paint
          translate(size / 2.0, size / 2.0)
          scale(size / 32.0, size / 32.0)
          save do
            rotate(angle * deg2rad) unless angle == 0
            rotate(-30 * deg2rad)
            scale(1, sqrt3)
            shapes.each do |sh|
              move_to(*sh[0])
              sh.slice(1 .. -1).each do |(x, y)|
                line_to(x, y)
              end
              close_path
            end
          end
          if outline
            set_line_width 0.5
            set_source_rgba outline.get_red / 255.0, outline.get_green / 255.0, outline.get_blue / 255.0, 255 / 255.0
            stroke true
          end
          set_source_rgba color.get_red / 255.0, color.get_green / 255.0, color.get_blue / 255.0, 255 / 255.0
          fill
        end
      end

      buffer = "".b
      outport = Object.new
      outport.define_singleton_method(:write, ->(d) { buffer << d; d.bytesize })
      surface.write_to_png outport
      buffer
    end
  end

  @@driver = CairoDriver
end
