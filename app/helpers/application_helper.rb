module ApplicationHelper
  # Returns the right utility classes for a top-nav link, marking the
  # current section as active. A path is "active" when the current request
  # path begins with it (so /sites/123/edit still highlights "Sites").
  def nav_link_class(path)
    active = current_page?(path) || request.path.start_with?("#{path}/")
    base   = "inline-flex items-center h-16 px-3 text-sm border-b-2 transition"
    if active
      "#{base} border-amber-800 text-stone-900 font-medium"
    else
      "#{base} border-transparent text-stone-600 hover:text-stone-900 hover:border-stone-200"
    end
  end
end
