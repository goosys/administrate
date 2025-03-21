module Administrate
  class ApplicationController < ActionController::Base
    include Administrate::Authorizable
    include Administrate::CollectionPaginator
    include Administrate::CollectionSearchable
    include Administrate::CollectionSortable
    include Administrate::ControllerDeprecator
    include Administrate::ControllerI18n
    include Administrate::DashboardManager
    include Administrate::HtmlRenderer
    include Administrate::ResourceManager

    protect_from_forgery with: :exception

    def index
      respond_to do |format|
        format.html { respond_to_index_html }
        format.json { render json: collection_resources } # TODO
      end
    end

    def show
      respond_to do |format|
        format.html { respond_to_show_html }
        format.json { render json: requested_resource } # TODO
      end
    end

    def new
      respond_to do |format|
        format.html { respond_to_new_html }
      end
    end

    def edit
      respond_to do |format|
        format.html { respond_to_edit_html }
      end
    end

    def create
      respond_to do |format|
        if save_built_resource
          format.html { respond_to_create_html }
        else
          format.html { respond_to_create_error_html }
        end
      end
    end

    def update
      requested_resource.assign_attributes(resource_params) # TODO

      respond_to do |format|
        if save_requested_resource
          format.html { respond_to_update_html }
        else
          format.html { respond_to_update_error_html }
        end
      end
    end

    def destroy
      respond_to do |format|
        if requested_resource.destroy
          format.html { respond_to_destroy_html }
        else
          format.html { respond_to_destroy_error_html }
        end
      end
    end
  end
end
