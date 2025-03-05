require "administrate/base_dashboard"

module Blog
  class PostDashboard < Administrate::BaseDashboard
    ATTRIBUTE_TYPES = {
      id: Field::Number,
      title: Field::String,
      body: Field::Text,
      tags: Field::HasMany,
      published_at: Field::DateTime,
      created_at: Field::DateTime,
      updated_at: Field::DateTime
    }

    READ_ONLY_ATTRIBUTES = [
      :id,
      :created_at,
      :updated_at
    ]

    COLLECTION_ATTRIBUTES = [
      :id,
      :title,
      :tags,
      :published_at
    ]

    FORM_ATTRIBUTES = ATTRIBUTE_TYPES.keys
    SHOW_PAGE_ATTRIBUTES = ATTRIBUTE_TYPES.keys

    def display_resource(resource)
      resource.title
    end
  end
end
