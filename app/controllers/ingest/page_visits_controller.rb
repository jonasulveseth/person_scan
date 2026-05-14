module Ingest
  class PageVisitsController < BaseController
    before_action :load_visitor

    def page_visit
      leaving = ActiveModel::Type::Boolean.new.cast(params[:leave])
      click_data = nil
      if leaving && ActiveModel::Type::Boolean.new.cast(params[:click])
        click_data = {
          element_href: params[:element_href],
          element_id: params[:element_id],
          element_x: params[:element_x],
          element_y: params[:element_y],
          element_html: params[:element_html]
        }
      end

      PageVisit.create!(
        visitor: @visitor,
        site: @site,
        url: params[:url],
        visit_time: params[:visit_time],
        leave: leaving,
        click_data: click_data
      )
      enqueue_classification
      head :no_content
    end
  end
end
