module Administrate
  module CollectionSearchable
    extend ActiveSupport::Concern

    private
    
    def filter_resources(resources)
      Administrate::Search.new(
        resources,
        dashboard,
        search_term
      ).run
    end

    def search_term
      @search_term ||= params[:search].to_s.strip
    end
  end
end
