# frozen_string_literal: true

module StatAnchorsHelper
  def stat_anchor_attrs(anchor)
    {}.tap do |attrs|
      attrs[:class] = %w[nav-link gl-display-flex gl-align-items-center] << extra_classes(anchor)
      attrs[:itemprop] = anchor.itemprop if anchor.itemprop
      attrs[:data] = anchor.data if anchor.data
    end
  end

  private

  def new_button_attribute(anchor)
    anchor.class_modifier || 'btn-link gl-text-blue-500!'
  end

  def button_attribute(anchor)
    anchor.class_modifier || 'btn-dashed'
  end

  def extra_classes(anchor)
    if Feature.enabled?(:project_overview_reorg)
      if anchor.is_link
        'stat-link gl-px-0! gl-pb-2!'
      else
        "stat-link gl-px-0! gl-pb-2! #{new_button_attribute(anchor)}"
      end
    elsif anchor.is_link
      'stat-link'
    else
      button_attribute(anchor)
    end
  end
end
