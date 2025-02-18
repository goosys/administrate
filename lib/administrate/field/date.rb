require_relative "base"

module Administrate
  module Field
    class Date < Base
      def date
        I18n.localize(
          data.in_time_zone(timezone).to_date,
          format: format
        )
      end

      private

      def format
        options.fetch(:format, :default)
      end

      def timezone
        options.fetch(:timezone, ::Time.zone)
      end
    end
  end
end
