module Administrate
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception

    def index
      authorize_resource(resource_class)
      search_term = params[:search].to_s.strip
      authorized_scope = authorize_scope(scoped_resource)
      resources = filter_resources(authorized_scope, search_term: search_term)
      resources = apply_collection_includes(resources)
      resources = order.apply(resources)
      resources = paginate_resources(resources)
      page = Administrate::Page::Collection.new(dashboard, order: order)
      page.context = self

      render locals: {
        resources: resources,
        search_term: search_term,
        page: page,
        show_search_bar: show_search_bar?
      }
    end

    def show
      page = Administrate::Page::Show.new(dashboard, requested_resource)
      page.context = self
      render locals: {
        page: page
      }
    end

    def new
      resource = new_resource.tap do |resource|
        authorize_resource(resource)
        contextualize_resource(resource)
      end

      page = Administrate::Page::Form.new(dashboard, resource)
      page.context = self
      render locals: {
        page: page
      }
    end

    def edit
      page = Administrate::Page::Form.new(dashboard, requested_resource)
      page.context = self
      render locals: {
        page: page
      }
    end

    def create
      resource = new_resource(resource_params).tap do |resource|
        authorize_resource(resource)
        contextualize_resource(resource)
      end

      if resource.save
        yield(resource) if block_given?
        redirect_to(
          after_resource_created_path(resource),
          notice: translate_with_resource("create.success")
        )
      else
        page = Administrate::Page::Form.new(dashboard, resource)
        page.context = self
        render :new, locals: {
          page: page
        }, status: :unprocessable_entity
      end
    end

    def update
      if requested_resource.update(resource_params)
        redirect_to(
          after_resource_updated_path(requested_resource),
          notice: translate_with_resource("update.success"),
          status: :see_other
        )
      else
        page = Administrate::Page::Form.new(dashboard, requested_resource)
        page.context = self
        render :edit, locals: {
          page: page
        }, status: :unprocessable_entity
      end
    end

    def destroy
      if requested_resource.destroy
        flash[:notice] = translate_with_resource("destroy.success")
      else
        flash[:error] = requested_resource.errors.full_messages.join("<br/>")
      end
      redirect_to after_resource_destroyed_path(requested_resource), status: :see_other
    end

    private

    def filter_resources(resources, search_term:)
      Administrate::Search.new(
        resources,
        dashboard,
        search_term
      ).run
    end

    def after_resource_destroyed_path(_requested_resource)
      {action: :index}
    end

    def after_resource_created_path(requested_resource)
      [namespace, requested_resource]
    end

    def after_resource_updated_path(requested_resource)
      [namespace, requested_resource]
    end

    helper_method :nav_link_state
    def nav_link_state(resource)
      underscore_resource = resource.to_s.split("/").join("__")
      (resource_name.to_s.pluralize == underscore_resource) ? :active : :inactive
    end

    # Whether the named action route exists for the resource class.
    #
    # @param resource [Class, String, Symbol] A class of resources, or the name
    #   of a class of resources.
    # @param action_name [String, Symbol] The name of an action that might be
    #   possible to perform on a resource or resource class.
    # @return [Boolean] `true` if a route exists for the resource class and the
    #   action. `false` otherwise.
    def existing_action?(resource, action_name)
      routes.include?([resource.to_s.underscore.pluralize, action_name.to_s])
    end
    helper_method :existing_action?

    # @deprecated Use {#existing_action} instead. Note that, in
    #   {#existing_action}, the order of parameters is reversed and
    #   there is no default value for the `resource` parameter.
    def valid_action?(action_name, resource = resource_class)
      Administrate.warn_of_deprecated_authorization_method(__method__)
      existing_action?(resource, action_name)
    end
    helper_method :valid_action?

    def routes
      @routes ||= Namespace.new(namespace).routes.to_set
    end

    def records_per_page
      params[:per_page] || 20
    end

    def order
      @order ||= Administrate::Order.new(
        sorting_attribute,
        sorting_direction,
        sorting_column: sorting_column(
          dashboard_attribute(sorting_attribute)
        )
      )
    end

    def sorting_column(dashboard_attribute)
      return unless dashboard_attribute.try(:options)

      dashboard_attribute.options.fetch(:sorting_column) {
        dashboard_attribute.options.fetch(:order, nil)
      }
    end

    def dashboard_attribute(attribute)
      dashboard.attribute_types[attribute.to_sym] if attribute
    end

    def sorting_attribute
      sorting_params.fetch(:order) { default_sorting_attribute }
    end

    def default_sorting_attribute
      nil
    end

    def sorting_direction
      sorting_params.fetch(:direction) { default_sorting_direction }
    end

    def default_sorting_direction
      nil
    end

    def sorting_params
      Hash.try_convert(request.query_parameters[resource_name]) || {}
    end

    def dashboard
      @dashboard ||= dashboard_class.new
    end

    def requested_resource
      @requested_resource ||= find_resource(params[:id]).tap do |resource|
        authorize_resource(resource)
        contextualize_resource(resource)
      end
    end

    # Override this method to specify custom lookup behavior.
    # This will be used to set the resource for the `show`, `edit`, `update` and `destroy` actions.
    #
    # @param param [ActiveSupport::Parameter]
    # @return [ActiveRecord::Base]
    def find_resource(param)
      authorize_scope(scoped_resource).find(param)
    end

    # Override this if you want to authorize the scope.
    # This will be used in all actions except for the `new` and `create` actions.
    #
    # @param scope [ActiveRecord::Relation]
    # @return [ActiveRecord::Relation]
    def authorize_scope(scope)
      scope
    end

    # Override this if you have certain roles that require a subset.
    # This will be used in all actions except for the `new` and `create` actions.
    #
    # @return [ActiveRecord::Relation]
    def scoped_resource
      resource_class.default_scoped
    end

    def apply_collection_includes(relation)
      resource_includes = dashboard.collection_includes
      return relation if resource_includes.empty?
      relation.includes(*resource_includes)
    end

    def resource_params
      params.require(resource_class.model_name.param_key)
        .permit(dashboard.permitted_attributes(action_name, self))
        .transform_values { |v| read_param_value(v) }
    end

    def read_param_value(data)
      if data.is_a?(ActionController::Parameters) && data[:type]
        if data[:type] == Administrate::Field::Polymorphic.to_s
          GlobalID::Locator.locate(data[:value])
        else
          raise "Unrecognised param data: #{data.inspect}"
        end
      elsif data.is_a?(ActionController::Parameters)
        data.transform_values { |v| read_param_value(v) }
      elsif data.is_a?(String) && data.blank?
        nil
      else
        data
      end
    end

    delegate :dashboard_class, :resource_class, :resource_name, :namespace,
      to: :resource_resolver
    helper_method :namespace
    helper_method :resource_name
    helper_method :resource_class

    def resource_resolver
      @resource_resolver ||=
        Administrate::ResourceResolver.new(controller_path)
    end

    def translate_with_resource(key)
      t(
        "administrate.controller.#{key}",
        resource: resource_resolver.resource_title
      )
    end

    def show_search_bar?
      dashboard.attribute_types_for(
        dashboard.all_attributes
      ).any? { |_name, attribute| attribute.searchable? }
    end

    # Whether the current user is authorized to perform the named action on the
    # resource.
    #
    # @param _resource [ActiveRecord::Base, Class, String, Symbol] The
    #   temptative target of the action, or the name of its class.
    # @param _action_name [String, Symbol] The name of an action that might be
    #   possible to perform on a resource or resource class.
    # @return [Boolean] `true` if the current user is authorized to perform the
    #   action on the resource. `false` otherwise.
    def authorized_action?(_resource, _action_name)
      true
    end
    helper_method :authorized_action?

    # @deprecated Use {#authorized_action} instead. Note that the order of
    #   parameters is reversed in {#authorized_action}.
    def show_action?(action, resource)
      Administrate.warn_of_deprecated_authorization_method(__method__)
      authorized_action?(resource, action)
    end
    helper_method :show_action?

    def new_resource(params = {})
      resource_class.new(params)
    end
    helper_method :new_resource

    # Override this if you want to authorize the resource differently.
    # This will be used to authorize the resource for the all actions without `index`.
    # In the case of `index`, it is used to authorize the resource class.
    #
    # @param resource [ActiveRecord::Base]
    # @return [ActiveRecord::Base]
    # @raise [Administrate::NotAuthorizedError] if the resource is not authorized.
    def authorize_resource(resource)
      if authorized_action?(resource, action_name)
        resource
      else
        raise Administrate::NotAuthorizedError.new(
          action: action_name,
          resource: resource
        )
      end
    end

    # Override this if you want to contextualize the resource differently.
    #
    # @param resource A resource to be contextualized.
    # @return nothing
    def contextualize_resource(resource)
    end

    def paginate_resources(resources)
      resources.page(params[:_page]).per(records_per_page)
    end
  end
end
