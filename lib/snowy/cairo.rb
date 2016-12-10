require_relative "common"
require "cairo"

module Snowy
  using Extentions

  module CairoDriver
    def self.render(size, triangles, background, color, outline, angle)
      deg2rad = Math::PI / 180
      surface = Cairo::ImageSurface.new(Cairo::Format::ARGB32, size, size)
      Cairo::Context.new(surface) do |context|
        context.instance_eval do
          set_line_width 0.5
          set_source_color [background.get_red / 255.0, background.get_green / 255.0, background.get_blue / 255.0, background.get_alpha / 255.0]
          paint
          translate(size / 2.0, size / 2.0)
          scale(size / 32.0, size / 32.0)
          rotate(angle * deg2rad) unless deg2rad == 0
          sqrt3 = Math.sqrt(3)
          [30, 90, 150, 210, 270, 330].each do |deg|
            save do
              rotate(-deg * deg2rad)
              scale(1, sqrt3)
              triangles.each do |(x1, y1, x2, y2, x3, y3)|
                move_to(x1, y1)
                line_to(x2, y2)
                line_to(x3, y3)
                close_path
              end
            end
          end
          if outline
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
