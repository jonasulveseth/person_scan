module Ingest
  class LinkClicksController < BaseController
    before_action :load_visitor

    def link_click
      ClickEvent.create!(
        visitor: @visitor,
        site: @site,
        url: params[:url],
        click_time: params[:click_time],
        link_id: params[:link_id],
        link_href: params[:link_href],
        link_contents: params[:link_contents],
        link_x: params[:link_x],
        link_y: params[:link_y],
        link_size: params[:link_size],
        click_x: params[:click_x],
        click_y: params[:click_y],
        overtime: params[:overtime],
        mouse_speed: parse_csv_ints(params[:mouse_speed]),
        mouse_acceleration: parse_csv_ints(params[:mouse_acceleration]),
        text_analyze: params[:text_analyze]
      )
      head :no_content
    end

    private

    def parse_csv_ints(v)
      return [] if v.nil? || v == ""
      v.to_s.split(",").map { |x| Integer(x, exception: false) }.compact
    end
  end
end
