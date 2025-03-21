module Administrate
  module View
    class SearchBar < Base
      def initialize(options={})
        @options = options
      end

      def render_in(view_context)
        @view_context = view_context
        return unless @options.fetch(:render?, true)
        return unless show_search_bar?
        view_context.render template_name, local_assigns
      end

      private

      def template_name
        "search"
      end

      def local_assigns
        {
          label: label,
          search_term: @options.fetch(:search_term),
          clear_search_params: clear_search_params
        }
      end

      def display_resource_name
        @view_context.display_resource_name @options.fetch(:resource_name)
      end

      def label
        I18n.t("administrate.search.label", resource: display_resource_name)
      end

      def clear_search_params
        @view_context.controller.params.except(:search, :_page).permit(
          :per_page, @options.fetch(:resource_name) => %i[order direction]
        )
      end

      def show_search_bar?
        @options.fetch(:dashboard).attribute_types_for(
          @options.fetch(:dashboard).all_attributes
        ).any? { |_name, attribute| attribute.searchable? }
      end
    end
  end
end
