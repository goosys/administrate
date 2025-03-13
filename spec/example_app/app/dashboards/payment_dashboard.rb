require "administrate/field/receipt_link"
require "administrate/base_dashboard"

class PaymentDashboard < Administrate::BaseDashboard
  ATTRIBUTE_TYPES = {
    id: Field::Number,
    receipt: Field::ReceiptLink,
    created_at: Field::DateTime,
    updated_at: Field::DateTime,
    order: Field::BelongsTo.with_options(
      associated_dashboard_class: Class.new(Administrate::BaseDashboard) do |klass|
        def display_resource(resource)
          "(Dynamic) Order ##{resource.id}"
        end
      end
    )
  }

  COLLECTION_ATTRIBUTES = [
    :id,
    :receipt,
    :order
  ]

  SHOW_PAGE_ATTRIBUTES = ATTRIBUTE_TYPES.keys
end
