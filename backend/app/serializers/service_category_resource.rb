class ServiceCategoryResource
  include Alba::Resource

  attributes :slug, :icon, :inspection_allowed
  attribute(:name) { |c| c.name }
  attribute(:description) { |c| c.description }
  attribute(:children) do |c|
    c.children.select { |child| child.active? && child.deleted_at.nil? }.map { |child| ServiceCategoryResource.new(child).to_h }
  end
end
