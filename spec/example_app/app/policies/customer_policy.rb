class CustomerPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user.admin?
        scope
      else
        scope.where(id: user.id)
      end
    end
  end

  def become?
    true
  end
end
